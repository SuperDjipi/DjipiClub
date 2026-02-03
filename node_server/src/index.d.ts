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
import { WebSocket } from 'ws';
import type { IGame } from './models/games/IGame.js';
/**
 * La "base de données" en mémoire pour toutes les parties actives.
 * C'est une Map qui associe un identifiant de partie (`gameId`) à son interface de jeu (`IGame`).
 * NOTE : Ces données sont volatiles et seront perdues si le serveur redémarre.
 */
export declare const games: Map<string, IGame>;
/**
 * La gestion des connexions WebSocket actives.
 * C'est une structure de données imbriquée :
 * Map<gameId, Map<playerId, WebSocket>>
 * - La clé externe est l'ID de la partie.
 * - La valeur est une autre Map qui associe l'ID d'un joueur (`playerId`) à son instance WebSocket.
 * Cela nous permet de savoir qui est qui et d'envoyer des messages ciblés.
 */
export declare const connections: Map<string, Map<string, WebSocket>>;
/**
 * Initialise le conteneur de connexions pour une partie donnée si ce n'est pas déjà fait.
 */
export declare function initGameConnections(gameId: string): void;
/**
 * Diffuse (broadcast) un nouvel état de jeu à tous les joueurs connectés
 * à une partie spécifique. Chaque joueur reçoit une version personnalisée de l'état.
 *
 * @param gameId L'ID de la partie à notifier.
 * @param game L'interface de jeu.
 */
export declare function broadcastGameState(gameId: string, game: IGame): void;
//# sourceMappingURL=index.d.ts.map