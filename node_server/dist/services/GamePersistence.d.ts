import type { Database } from 'sqlite';
import type { IGame } from '../models/games/IGame.js';
export declare class GamePersistence {
    private db;
    constructor(database: Database);
    /**
     * Sauvegarde une partie dans la DB
     */
    saveGame(game: IGame): Promise<void>;
    /**
     * Charge une partie depuis la DB
     */
    loadGame(gameId: string): Promise<IGame | null>;
    /**
     * Charge toutes les parties actives au démarrage
     */
    loadAllActiveGames(): Promise<Map<string, IGame>>;
    /**
     * Supprime une partie terminée (nettoyage)
     */
    deleteGame(gameId: string): Promise<void>;
    /**
     * Nettoie les parties finies de plus de 7 jours
     */
    cleanOldGames(): Promise<void>;
}
//# sourceMappingURL=GamePersistence.d.ts.map