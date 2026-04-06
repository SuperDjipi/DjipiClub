import { GameStatus } from '../models/games/IGame.js';
import { GameFactory } from '../games/GameFactory.js';
export class GamePersistence {
    db;
    constructor(database) {
        this.db = database;
    }
    /**
     * Sauvegarde une partie dans la DB
     */
    async saveGame(game) {
        try {
            const serialized = game.serialize();
            await this.db.run(`INSERT OR REPLACE INTO games (id, gameState, status, lastUpdated)
                 VALUES (?, ?, ?, datetime('now'))`, [game.id, serialized, game.status]);
            console.log(`💾 Partie ${game.id} sauvegardée`);
        }
        catch (error) {
            console.error(`❌ Erreur sauvegarde partie ${game.id}:`, error);
        }
    }
    /**
     * Charge une partie depuis la DB
     */
    async loadGame(gameId) {
        try {
            const row = await this.db.get('SELECT gameState FROM games WHERE id = ?', gameId);
            if (row) {
                const game = GameFactory.deserializeGame(row.gameState);
                console.log(`📂 Partie ${gameId} chargée`);
                return game;
            }
            return null;
        }
        catch (error) {
            console.error(`❌ Erreur chargement partie ${gameId}:`, error);
            return null;
        }
    }
    /**
     * Charge toutes les parties actives au démarrage
     */
    async loadAllActiveGames() {
        const gamesMap = new Map();
        try {
            const rows = await this.db.all(`SELECT gameState FROM games
                 WHERE status IN (?, ?)
                 ORDER BY lastUpdated DESC`, [GameStatus.WAITING_FOR_PLAYERS, GameStatus.PLAYING]);
            for (const row of rows) {
                try {
                    const game = GameFactory.deserializeGame(row.gameState);
                    gamesMap.set(game.id, game);
                }
                catch (err) {
                    console.error('❌ Erreur désérialisation partie:', err);
                }
            }
            console.log(`📂 ${gamesMap.size} partie(s) active(s) chargée(s)`);
        }
        catch (error) {
            console.error('❌ Erreur chargement parties:', error);
        }
        return gamesMap;
    }
    /**
     * Supprime une partie terminée (nettoyage)
     */
    async deleteGame(gameId) {
        try {
            await this.db.run('DELETE FROM games WHERE id = ?', gameId);
            console.log(`🗑️ Partie ${gameId} supprimée de la DB`);
        }
        catch (error) {
            console.error(`❌ Erreur suppression partie ${gameId}:`, error);
        }
    }
    /**
     * Nettoie les parties finies de plus de 7 jours
     */
    async cleanOldGames() {
        try {
            const result = await this.db.run(`DELETE FROM games
                 WHERE status = ?
                 AND lastUpdated < datetime('now', '-7 days')`, GameStatus.FINISHED);
            console.log(`🧹 ${result.changes} partie(s) ancienne(s) nettoyée(s)`);
        }
        catch (error) {
            console.error('❌ Erreur nettoyage:', error);
        }
    }
}
//# sourceMappingURL=GamePersistence.js.map