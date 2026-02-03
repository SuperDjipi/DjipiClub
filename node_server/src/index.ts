/**
 * Ce fichier est le point d'entrée principal et le cœur du serveur de jeu Node.js.
 * Il est responsable de :
 * 1. Démarrer un serveur web Express.
 * 2. Lancer un serveur WebSocket par-dessus le serveur Express pour la communication en temps réel.
 * 3. Gérer les connexions, déconnexions et messages des clients.
 * 4. Maintenir l'état de toutes les parties en mémoire.
 * 5. Agir comme un "contrôleur" qui reçoit les événements des clients et délègue la logique
 *    de jeu aux gestionnaires de jeux spécifiques.
 */

import express from 'express';
import { WebSocketServer, WebSocket } from 'ws';
// Import des modèles génériques
import type { IGame, Player } from './models/games/IGame.js';
import { GameType, GameStatus } from './models/games/IGame.js';
import { GameFactory } from './games/GameFactory.js';
import { v4 as generateUUID } from 'uuid';
import { initializeDatabase } from './db/database.js';
import { handleNewConnection } from './services/webSocketManager.js';
import { handleLobbyConnection, getLobbyPlayers } from './services/lobbyChatManager.js';
import { GamePersistence } from './services/GamePersistence.js';
import cors from 'cors';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import https from 'https';
import fs from 'fs';

// Pour __dirname en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// --- GESTION DES PARTIES EN MÉMOIRE ---

/**
 * La "base de données" en mémoire pour toutes les parties actives.
 * C'est une Map qui associe un identifiant de partie (`gameId`) à son interface de jeu (`IGame`).
 * NOTE : Ces données sont volatiles et seront perdues si le serveur redémarre.
 */
export const games = new Map<string, IGame>();

/**
 * La gestion des connexions WebSocket actives.
 * C'est une structure de données imbriquée :
 * Map<gameId, Map<playerId, WebSocket>>
 * - La clé externe est l'ID de la partie.
 * - La valeur est une autre Map qui associe l'ID d'un joueur (`playerId`) à son instance WebSocket.
 * Cela nous permet de savoir qui est qui et d'envoyer des messages ciblés.
 */
export const connections = new Map<string, Map<string, WebSocket>>();

let gamePersistence: GamePersistence;

/**
 * Initialise le conteneur de connexions pour une partie donnée si ce n'est pas déjà fait.
 */
export function initGameConnections(gameId: string) {
    if (!connections.has(gameId)) {
        connections.set(gameId, new Map<string, WebSocket>());
    }
}
/**
 * Génère un code de partie simple de 4 lettres majuscules.
 */
function generateGameCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    let code = '';
    for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    // TODO: Plus tard, on vérifiera que ce code n'est pas déjà utilisé.
    return code;
}




/**
 * Diffuse (broadcast) un nouvel état de jeu à tous les joueurs connectés
 * à une partie spécifique. Chaque joueur reçoit une version personnalisée de l'état.
 *
 * @param gameId L'ID de la partie à notifier.
 * @param game L'interface de jeu.
 */
export function broadcastGameState(gameId: string, game: IGame) {
    const gameConnections = connections.get(gameId);
    if (!gameConnections) {
        console.warn(`Tentative de diffusion à une partie inexistante ou sans connexions : ${gameId}`);
        return;
    }

    console.log(`📣 Diffusion du nouvel état pour la partie ${gameId} à ${gameConnections.size} joueur(s)...`);

    // Récupérer le handler d'événements pour ce type de jeu
    const eventHandler = GameFactory.getEventHandler(game.type);

    // On boucle sur tous les joueurs définis dans le jeu
    game.players.forEach(player => {
        const clientWs = gameConnections.get(player.id);

        // On vérifie si ce joueur est bien connecté
        if (clientWs && clientWs.readyState === WebSocket.OPEN) {
            // 1. On crée l'événement de mise à jour personnalisé via le handler
            const updateEvent = eventHandler.createStateUpdateEvent(game, player.id);

            // 2. On envoie l'événement au client
            clientWs.send(JSON.stringify(updateEvent));
            console.log(`   - État envoyé à ${player.name} (${player.id})`);
        } else {
            console.log(`   - Joueur ${player.name} non connecté, envoi ignoré.`);
        }
    });

    // Sauvegarder en DB
    if (gamePersistence) {
        gamePersistence.saveGame(game);
    }
}

// --- DÉMARRAGE DU SERVEUR ---

async function startServer() {
    const db = await initializeDatabase(); // On initialise la DB en premier
    gamePersistence = new GamePersistence(db);
    
    // Charger les parties existantes
    const loadedGames = await gamePersistence.loadAllActiveGames();
    for (const [gameId, gameState] of loadedGames) {
        games.set(gameId, gameState);
        initGameConnections(gameId);
    }
    console.log(`🎮 ${games.size} partie(s) en mémoire`);
    
    // Nettoyage périodique (toutes les 24h)
    setInterval(() => {
        gamePersistence.cleanOldGames();
    }, 24 * 60 * 60 * 1000);
    
    const app = express();

    app.use(cors({
        origin: function (origin, callback) {
            if (!origin || 
                origin.startsWith('http://localhost') || 
                origin.startsWith('https://localhost') ||  // ← HTTPS localhost
                origin.startsWith('http://192.168.') ||
                origin.startsWith('https://192.168.') ||   // ← HTTPS IP locale
                origin.startsWith('https://play/lapoumerole.fr') || 
                origin.startsWith('https://djipi.club')) { // ← Production
                callback(null, true);
            } else {
                console.log('❌ CORS refusé pour:', origin);
                callback(new Error('Not allowed by CORS'));
            }
        },
        credentials: true
    }));

    app.use('/play', express.static(path.join(__dirname, '../public/djipi-web'), {
        setHeaders: (res, filePath) => {
            // Headers CORS et WASM obligatoires
            res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
            res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
            
            // Headers PWA
            res.setHeader('Service-Worker-Allowed', '/play');
            
            // Types MIME
            if (filePath.endsWith('.wasm')) {
                res.setHeader('Content-Type', 'application/wasm');
            }
            if (filePath.endsWith('.js')) {
                res.setHeader('Content-Type', 'application/javascript');
            }
            if (filePath.endsWith('.json')) {
                res.setHeader('Content-Type', 'application/json');
            }
        }
    }));
    
    // Route pour le manifest PWA
    app.get('/play/manifest.json', (req, res) => {
        res.json({
            "name": "Djipi Club - Scrabble Multijoueur",
            "short_name": "Djipi Club",
            "description": "Jouez au Scrabble en multijoueur",
            "start_url": "/play",
            "display": "fullscreen",
            "orientation": "portrait",
            "background_color": "#1a1a1a",
            "theme_color": "#1a1a1a",
            "icons": [
                {
                    "src": "/play/icon_144.png",
                    "sizes": "144x144",
                    "type": "image/png"
                },
                {
                    "src": "/play/icon_180.png",
                    "sizes": "180x180",
                    "type": "image/png"
                },
                {
                    "src": "/play/icon_512.png",
                    "sizes": "512x512",
                    "type": "image/png"
                }
            ]
        });
    });
    
    // Middleware pour servir les fichiers statiques (HTML, CSS, JS) du dossier 'public'.
    app.use(express.static('public'));
    // Middleware pour permettre à Express de comprendre le JSON envoyé dans le corps des requêtes POST.
    app.use(express.json());

    const port = 8080;
    
    // HTTPS avec certificat auto-signé
    const httpsOptions = {
        key: fs.readFileSync(path.join(__dirname, '../key.pem')),
        cert: fs.readFileSync(path.join(__dirname, '../cert.pem'))
    };
    
    const server = https.createServer(httpsOptions, app);
    
    server.listen(port, '0.0.0.0', () => {
        console.log(`✅ Serveur DC HTTPS sur https://0.0.0.0:${port}`);
        console.log(`📱 Local : https://${getLocalIP()}:${port}`);
    });
//    const server = app.listen(port, () => {
//        console.log(`✅ Serveur démarré et à l'écoute sur http://localhost:${port}`);
//    });
    const wss = new WebSocketServer({ server });

    // --- DÉBUT DE L'API D'INSCRIPTION ---

    /**
     * Route API pour l'inscription d'un nouveau joueur.
     * Attend une requête POST sur /api/register avec un corps JSON
     * contenant 'name' et 'password'.*/
    app.post('/api/register', async (req, res) => {// La fonction devient async
        const { name, password } = req.body;
        if (!name || !password) {
            return res.status(400).send({ message: "Le pseudo et le mot de passe sont requis." });
        }

        try {
            // On vérifie si le nom existe déjà dans la base de données
            const existingUser = await db.get('SELECT * FROM users WHERE LOWER(name) = ?', name.toLowerCase());
            if (existingUser) {
                return res.status(409).send({ message: "Ce pseudo est déjà pris." });
            }

            // Création du profil
            const newPlayerId = generateUUID();
            const hashedPassword = password; // TODO: HASH ME!

            // On exécute la requête SQL pour insérer le nouvel utilisateur
            await db.run(
                'INSERT INTO users (id, name, hashedPassword) VALUES (?, ?, ?)',
                [newPlayerId, name, hashedPassword]
            );

            console.log(`✅ Nouveau joueur inséré dans la DB : ${name}`);
            res.status(201).send({ message: `Profil pour '${name}' créé avec succès !`, playerId: newPlayerId });

        } catch (error) {
            console.error("Erreur lors de l'inscription:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });
    // --- FIN DE L'API D'INSCRIPTION ---

    /**
     * Route API pour la connexion d'un joueur existant.
     * Attend une requête GET sur /api/login?name=PSEUDO
     */
    app.get('/api/login', async (req, res) => {
        const name = req.query.name as string;

        if (!name) {
            return res.status(400).send({ message: "Le pseudo est requis." });
        }

        try {
            // Chercher le joueur dans la base de données
            const user = await db.get('SELECT * FROM users WHERE LOWER(name) = ?', name.toLowerCase());

            if (!user) {
                return res.status(404).send({ message: "Joueur non trouvé. Veuillez vous inscrire." });
            }

            console.log(`✅ Connexion réussie pour : ${user.name}`);
            res.status(200).send({
                message: `Bienvenue à nouveau, ${user.name} !`,
                playerId: user.id,
                name: user.name
            });

        } catch (error) {
            console.error("Erreur lors de la connexion:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });

    /**
     * Route API pour récupérer la liste des parties en cours pour un joueur spécifique.
     */
    app.get('/api/players/:playerId/games', (req, res) => {
        const { playerId } = req.params;

        if (!playerId) {
            return res.status(400).send({ message: "L'ID du joueur est requis." });
        }

        // On parcourt toutes les parties en mémoire.
        const activeGamesForPlayer = Array.from(games.values())
            .filter(game => game.hasPlayer(playerId)) // On ne garde que les parties où le joueur est présent
            .filter(game => game.status !== GameStatus.FINISHED) // On exclut les parties terminées
            .map(game => {
                // Pour chaque partie, on identifie les adversaires
                const opponents = game.players
                    .filter(p => p.id !== playerId) // On exclut le joueur lui-même
                    .map(p => p.name); // On ne garde que leur nom

                const currentPlayer = game.players[game.currentPlayerIndex];

                // On construit un objet propre et utile pour l'UI du client
                // Note: tileCount est spécifique à Scrabble, on le récupère via le cast si c'est du Scrabble
                const scrabbleGame = game as any;
                const tileCount = scrabbleGame.tileBag?.length ?? 0;

                return {
                    gameId: game.id, // L'UUID, essentiel pour se reconnecter
                    gameType: game.type, // Type de jeu
                    opponents: opponents.length > 0 ? opponents : ["En attente..."], // Liste des noms des adversaires
                    isMyTurn: currentPlayer?.id === playerId, // Est-ce mon tour ?
                    status: game.status,
                    tileCount: tileCount,
                    myScore: game.players.find(p => p.id === playerId)?.score || 0,
                    opponentScore: game.players.find(p => p.id !== playerId)?.score || 0 // Simplifié pour 2 joueurs
                };
            });

        console.log(`🔎 Requête pour les parties de ${playerId}. ${activeGamesForPlayer.length} partie(s) trouvée(s).`);

        res.status(200).json(activeGamesForPlayer);
    });

    /**
     * Route API pour permettre à un joueur de rejoindre une partie existante.
     * Attend une requête POST sur /api/games/:gameId/join
     * @param gameId L'ID de la partie à rejoindre (dans l'URL).
     * @body { "playerId": "xxxx-yyyy-zzzz" }
     */
    app.post('/api/games/:gameId/join', async (req, res) => {
        const { gameId } = req.params; // On récupère l'ID de la partie depuis l'URL
        const { playerId } = req.body; // On récupère l'ID du joueur depuis le corps de la requête

        if (!playerId) {
            return res.status(400).send({ message: "L'ID du joueur est requis." });
        }

        const game = games.get(gameId);

        // 1. Vérifications de base
        if (!game) {
            return res.status(404).send({ message: "Partie non trouvée." }); // 404 Not Found
        }
        if (game.status !== GameStatus.WAITING_FOR_PLAYERS) {
            return res.status(403).send({ message: "Cette partie a déjà commencé ou est terminée." }); // 403 Forbidden
        }
        if (game.hasPlayer(playerId)) {
            // Le joueur est déjà dans la partie, on le laisse juste continuer.
            console.log(`ℹ️ Le joueur ${playerId} tente de rejoindre une partie où il est déjà.`);
            return res.status(200).send({ message: "Vous êtes déjà dans la partie.", gameId: game.id });
        }

        try {
            // 2. Récupérer le profil du joueur depuis la base de données
            const userProfile = await db.get('SELECT * FROM users WHERE id = ?', playerId);
            if (!userProfile) {
                return res.status(404).send({ message: "Profil joueur non trouvé dans la base de données." });
            }

            // 3. Ajouter le joueur à l'état de la partie via l'interface IGame
            const newPlayer: Player = {
                id: userProfile.id,
                name: userProfile.name,
                score: 0,
                isActive: false
            };
            game.addPlayer(newPlayer);

            console.log(`✅ Le joueur ${userProfile.name} a rejoint la partie ${gameId}`);

            // 4. NOTIFIER TOUT LE MONDE en temps réel !
            broadcastGameState(gameId, game);

            // 5. DÉMARRER AUTOMATIQUEMENT SI assez de joueurs
            if (game.canStart()) {
                console.log(`🎮 Démarrage automatique de la partie ${gameId} (${game.players.length} joueurs)`);

                // Attendre un court instant pour que tous les clients soient connectés
                setTimeout(() => {
                    const currentGame = games.get(gameId);
                    if (!currentGame || currentGame.status !== GameStatus.WAITING_FOR_PLAYERS) {
                        return; // La partie a déjà été démarrée ou n'existe plus
                    }

                    // Utiliser la méthode start() de l'interface IGame
                    currentGame.start();

                    // Sauvegarder et diffuser le nouvel état
                    broadcastGameState(gameId, currentGame);

                    console.log(`✅ Partie ${gameId} démarrée automatiquement avec ${currentGame.players.length} joueurs`);
                }, 1000); // Délai de 1 seconde pour laisser le temps aux WebSockets de se connecter
            }

            // 6. Renvoyer une réponse de succès au joueur qui vient de rejoindre
            res.status(200).send({ message: "Vous avez rejoint la partie avec succès !", gameId: game.id });

        } catch (error) {
            console.error("Erreur pour rejoindre la partie:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });

    /**
     * Route API pour permettre à un joueur de se "reconnecter" à une partie déjà en cours.
     * Cette route est cruciale pour reprendre une partie après avoir fermé/rouvert l'application
     * ou pour rejoindre une partie de test déjà démarrée.
     * Attend une requête POST sur /api/games/:gameId/reconnect
     * @param gameId L'ID de la partie à rejoindre (dans l'URL).
     * @body { "playerId": "xxxx-yyyy-zzzz" }
     */
    app.post('/api/games/:gameId/reconnect', (req, res) => {
        const { gameId } = req.params;
        const { playerId } = req.body;

        if (!playerId) {
            return res.status(400).send({ message: "L'ID du joueur est requis." });
        }

        const game = games.get(gameId.toUpperCase());

        // 1. La partie doit exister
        if (!game) {
            return res.status(404).send({ message: "Partie non trouvée." });
        }

        // 2. Le joueur doit faire partie de cette partie
        if (!game.hasPlayer(playerId)) {
            return res.status(403).send({ message: "Vous ne faites pas partie de cette partie." });
        }

        // 3. La partie doit être en cours (ou terminée, on peut vouloir voir le score final)
        if (game.status === GameStatus.WAITING_FOR_PLAYERS) {
            return res.status(403).send({ message: "Cette partie n'a pas encore commencé. Utilisez l'API de 'join'." });
        }

        // Si toutes les conditions sont remplies, on autorise la reconnexion.
        console.log(`✅ Autorisation de reconnexion pour le joueur ${playerId} à la partie ${game.id}`);
        res.status(200).send({
            message: "Reconnexion autorisée. Établissement de la connexion WebSocket...",
            gameId: game.id,
        });
    });

    // --- DÉBUT DE L'API DE CRÉATION DE PARTIE ---
    /**
     * Route API pour créer une nouvelle partie.
     * @body { "playerId": "xxxx-yyyy-zzzz", "gameType": "SCRABBLE_CLASSIC" }
     */
    app.post('/api/games', async (req, res) => {
        const { playerId, gameType } = req.body;

        if (!playerId) {
            return res.status(400).send({ message: "L'ID du joueur est requis." });
        }

        try {
            const userProfile = await db.get('SELECT * FROM users WHERE id = ?', playerId);
            if (!userProfile) {
                return res.status(404).send({ message: "Profil joueur non trouvé." });
            }

            // Générer un code de partie unique
            const gameId = generateUUID();

            // Créer le jeu via GameFactory (par défaut SCRABBLE_CLASSIC)
            const type = (gameType as GameType) || GameType.SCRABBLE_CLASSIC;
            const newGame = GameFactory.createGame(type, gameId, playerId);

            // Ajouter le joueur hôte
            const hostPlayer: Player = {
                id: userProfile.id,
                name: userProfile.name,
                score: 0,
                isActive: false,
            };
            newGame.addPlayer(hostPlayer);

            // Sauvegarder la nouvelle partie en mémoire
            games.set(gameId, newGame);
            initGameConnections(gameId); // On prépare le "salon" WebSocket pour cette partie

            console.log(`✅ Nouvelle partie ${type} créée par ${userProfile.name}. ID: ${gameId}`);

            // Renvoyer une réponse de succès au client avec l'état pour le joueur
            const stateForPlayer = newGame.getStateForPlayer(playerId);
            res.status(201).send({
                gameId: newGame.id,
                gameType: newGame.type,
                status: newGame.status,
                ...stateForPlayer
            });
        } catch (error) {
            console.error("Erreur lors de la création de la partie:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });

    /**
 * Route API pour récupérer la liste de tous les joueurs
 */
    app.get('/api/players', async (req, res) => {
        try {
            // Récupérer tous les joueurs de la base de données
            const players = await db.all('SELECT id, name FROM users ORDER BY name');

            console.log(`🔎 Requête pour la liste des joueurs. ${players.length} joueur(s) trouvé(s).`);

            res.status(200).json(players);
        } catch (error) {
            console.error("Erreur lors de la récupération des joueurs:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });

    /**
     * Route API pour défier un joueur (créer une partie et l'inviter)
     * @body { "playerId": "xxxx-yyyy-zzzz", "gameType": "SCRABBLE_CLASSIC" }
     */
    app.post('/api/challenge/:opponentId', async (req, res) => {
        const { opponentId } = req.params;
        const { playerId, gameType } = req.body;  // L'ID de celui qui lance le défi

        if (!playerId) {
            return res.status(400).send({ message: "L'ID du joueur est requis." });
        }

        try {
            // Vérifier que les deux joueurs existent
            const challenger = await db.get('SELECT * FROM users WHERE id = ?', playerId);
            const opponent = await db.get('SELECT * FROM users WHERE id = ?', opponentId);

            if (!challenger || !opponent) {
                return res.status(404).send({ message: "Joueur introuvable." });
            }

            // Créer une nouvelle partie via GameFactory
            const gameId = generateGameCode();
            const type = (gameType as GameType) || GameType.SCRABBLE_CLASSIC;
            const newGame = GameFactory.createGame(type, gameId, playerId);

            // Ajouter les deux joueurs
            const firstPlayer: Player = {
                id: playerId,
                name: challenger.name,
                score: 0,
                isActive: true,
            };
            const secondPlayer: Player = {
                id: opponentId,
                name: opponent.name,
                score: 0,
                isActive: false,
            };

            newGame.addPlayer(firstPlayer);
            newGame.addPlayer(secondPlayer);

            // Démarrer la partie immédiatement
            newGame.start();

            games.set(gameId, newGame);
            initGameConnections(gameId);

            console.log(`✅ Partie ${type} créée par défi : ${gameId} (${challenger.name} vs ${opponent.name})`);

            // TODO: Envoyer une notification à l'adversaire (WebSocket, push notification, etc.)

            res.status(201).json({
                message: `Défi envoyé à ${opponent.name} !`,
                gameId: gameId
            });

            broadcastGameState(gameId, newGame);

        } catch (error) {
            console.error("Erreur lors de la création du défi:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });

    // --- ROUTE API POUR LES JOUEURS EN LIGNE (LOBBY) ---

    /**
     * Route API pour récupérer la liste des joueurs actuellement connectés au lobby
     */
    app.get('/api/lobby/players', (req, res) => {
        const onlinePlayers = getLobbyPlayers();
        res.status(200).json(onlinePlayers);
    });

    // --- LOGIQUE PRINCIPALE DE CONNEXION ---

    /**
     * Ce bloc est exécuté à chaque fois qu'un nouveau client établit une connexion WebSocket.
     * On distingue les connexions au lobby (chat) des connexions aux parties.
     */
    wss.on('connection', (ws, req) => {
        const url = new URL(req.url!, `http://${req.headers.host}`);
        const path = url.pathname;

        if (path === '/lobby') {
            // Connexion au lobby pour le chat
            handleLobbyConnection(ws, req, db);
        } else {
            // Connexion à une partie de jeu
            handleNewConnection(ws, req);
        }
    });
}

// On lance le serveur
startServer().catch(error => {
    console.error("Impossible de démarrer le serveur:", error);
});

function getLocalIP(): string {
    const nets = os.networkInterfaces();
    if (!nets) return 'localhost';
    
    for (const name of Object.keys(nets)) {
        const netInterface = nets[name];
        if (!netInterface) continue;
        
        for (const net of netInterface) {
            // IPv4, pas localhost
            if (net.family === 'IPv4' && !net.internal) {
                return net.address;
            }
        }
    }
    return 'localhost';
}
