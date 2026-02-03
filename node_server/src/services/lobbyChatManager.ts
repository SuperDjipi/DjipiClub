/**
 * LOBBY CHAT MANAGER
 * Gère les connexions WebSocket pour le chat du lobby (hors jeu).
 * Permet aux joueurs de discuter dans un salon commun.
 */

import WebSocket from 'ws';
import { URL } from 'url';

// Types pour les événements de chat
interface ChatMessage {
    type: 'CHAT_MESSAGE';
    payload: {
        message: string;
    };
}

interface ChatBroadcast {
    type: 'CHAT_BROADCAST';
    payload: {
        from: string;
        message: string;
        timestamp: number;
    };
}

interface PlayerJoined {
    type: 'PLAYER_JOINED';
    payload: {
        playerId: string;
        playerName: string;
        onlinePlayers: string[];
    };
}

interface PlayerLeft {
    type: 'PLAYER_LEFT';
    payload: {
        playerId: string;
        playerName: string;
        onlinePlayers: string[];
    };
}

type LobbyEvent = ChatMessage;
type LobbyBroadcast = ChatBroadcast | PlayerJoined | PlayerLeft;

// Structure pour stocker les infos d'un joueur connecté au lobby
interface LobbyPlayer {
    ws: WebSocket;
    playerId: string;
    playerName: string;
}

// Map des joueurs connectés au lobby: playerId -> LobbyPlayer
const lobbyConnections = new Map<string, LobbyPlayer>();

/**
 * Récupère le nom d'un joueur depuis la base de données
 */
async function getPlayerName(db: any, playerId: string): Promise<string | null> {
    try {
        const user = await db.get('SELECT name FROM users WHERE id = ?', playerId);
        return user?.name || null;
    } catch (error) {
        console.error('Erreur lors de la récupération du nom du joueur:', error);
        return null;
    }
}

/**
 * Retourne la liste des noms des joueurs actuellement en ligne
 */
function getOnlinePlayerNames(): string[] {
    return Array.from(lobbyConnections.values()).map(p => p.playerName);
}

/**
 * Diffuse un message à tous les joueurs connectés au lobby
 */
function broadcastToLobby(event: LobbyBroadcast, excludePlayerId?: string) {
    const message = JSON.stringify(event);

    lobbyConnections.forEach((player, playerId) => {
        if (excludePlayerId && playerId === excludePlayerId) {
            return; // On n'envoie pas au joueur exclu
        }

        if (player.ws.readyState === WebSocket.OPEN) {
            player.ws.send(message);
        }
    });
}

/**
 * Gère une nouvelle connexion WebSocket au lobby
 */
export async function handleLobbyConnection(ws: WebSocket, req: any, db: any) {
    // Parser l'URL pour extraire le playerId
    const requestUrl = new URL(req.url!, `http://${req.headers.host}`);
    const playerId = requestUrl.searchParams.get('playerId');

    if (!playerId) {
        console.log('❌ Connexion lobby refusée: playerId manquant');
        ws.close();
        return;
    }

    // Récupérer le nom du joueur
    const playerName = await getPlayerName(db, playerId);
    if (!playerName) {
        console.log(`❌ Connexion lobby refusée: joueur ${playerId} non trouvé`);
        ws.close();
        return;
    }

    // Si le joueur est déjà connecté, fermer l'ancienne connexion
    const existingConnection = lobbyConnections.get(playerId);
    if (existingConnection) {
        existingConnection.ws.close();
    }

    // Enregistrer la nouvelle connexion
    const lobbyPlayer: LobbyPlayer = {
        ws,
        playerId,
        playerName
    };
    lobbyConnections.set(playerId, lobbyPlayer);

    console.log(`💬 ${playerName} a rejoint le lobby chat (${lobbyConnections.size} joueurs en ligne)`);

    // Notifier tout le monde qu'un joueur a rejoint
    const joinEvent: PlayerJoined = {
        type: 'PLAYER_JOINED',
        payload: {
            playerId,
            playerName,
            onlinePlayers: getOnlinePlayerNames()
        }
    };
    broadcastToLobby(joinEvent);

    // Gérer les messages entrants
    ws.on('message', (message) => {
        try {
            const event: LobbyEvent = JSON.parse(message.toString());

            if (event.type === 'CHAT_MESSAGE') {
                // Valider le message
                const text = event.payload.message?.trim();
                if (!text || text.length > 500) {
                    return; // Ignorer les messages vides ou trop longs
                }

                // Diffuser le message à tous
                const broadcastEvent: ChatBroadcast = {
                    type: 'CHAT_BROADCAST',
                    payload: {
                        from: playerName,
                        message: text,
                        timestamp: Date.now()
                    }
                };
                broadcastToLobby(broadcastEvent);

                console.log(`💬 [${playerName}]: ${text}`);
            }
        } catch (error) {
            console.error('Erreur lors du traitement du message lobby:', error);
        }
    });

    // Gérer la déconnexion
    ws.on('close', () => {
        lobbyConnections.delete(playerId);

        console.log(`👋 ${playerName} a quitté le lobby chat (${lobbyConnections.size} joueurs en ligne)`);

        // Notifier tout le monde qu'un joueur est parti
        const leaveEvent: PlayerLeft = {
            type: 'PLAYER_LEFT',
            payload: {
                playerId,
                playerName,
                onlinePlayers: getOnlinePlayerNames()
            }
        };
        broadcastToLobby(leaveEvent);
    });

    // Gérer les erreurs
    ws.on('error', (error) => {
        console.error(`Erreur WebSocket lobby pour ${playerName}:`, error);
    });
}

/**
 * Retourne le nombre de joueurs connectés au lobby
 */
export function getLobbyPlayerCount(): number {
    return lobbyConnections.size;
}

/**
 * Retourne la liste des joueurs connectés au lobby
 */
export function getLobbyPlayers(): Array<{ id: string; name: string }> {
    return Array.from(lobbyConnections.values()).map(p => ({
        id: p.playerId,
        name: p.playerName
    }));
}
