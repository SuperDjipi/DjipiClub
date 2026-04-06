/**
 * LOBBY CHAT MANAGER
 * Gère les connexions WebSocket pour le chat du lobby (hors jeu).
 * Permet aux joueurs de discuter dans un salon commun.
 */
import WebSocket from 'ws';
/**
 * Gère une nouvelle connexion WebSocket au lobby
 */
export declare function handleLobbyConnection(ws: WebSocket, req: any, db: any): Promise<void>;
/**
 * Retourne le nombre de joueurs connectés au lobby
 */
export declare function getLobbyPlayerCount(): number;
/**
 * Retourne la liste des joueurs connectés au lobby
 */
export declare function getLobbyPlayers(): Array<{
    id: string;
    name: string;
}>;
//# sourceMappingURL=lobbyChatManager.d.ts.map