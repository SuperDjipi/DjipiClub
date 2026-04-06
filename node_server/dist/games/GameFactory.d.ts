import { type IGame, GameType } from '../models/games/IGame.js';
import type { IGameEventHandler } from '../models/games/IGameEvents.js';
export declare class GameFactory {
    static createGame(type: GameType, gameId: string, hostId: string): IGame;
    /**
     * Retourne le gestionnaire d'événements pour un type de jeu donné.
     * Les handlers sont des singletons (une instance par type).
     */
    static getEventHandler(type: GameType): IGameEventHandler;
    /**
     * Désérialise une partie depuis sa représentation JSON.
     * Utilisé pour recharger les parties depuis la base de données.
     */
    static deserializeGame(jsonData: string): IGame;
    /**
     * Désérialise une partie Scrabble Classic
     */
    private static _deserializeScrabbleClassic;
    static getSupportedGames(): GameType[];
    static getGameInfo(type: GameType): {
        name: string;
        minPlayers: number;
        maxPlayers: number;
    };
}
//# sourceMappingURL=GameFactory.d.ts.map