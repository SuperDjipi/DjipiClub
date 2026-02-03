/**
 * Gestionnaire d'événements pour le jeu Scrabble.
 * Encapsule toute la logique de traitement des événements WebSocket spécifiques au Scrabble.
 */
import type { IGame } from '../../models/games/IGame.js';
import type { IGameEventHandler, IClientEvent, IServerEvent, EventResult } from '../../models/games/IGameEvents.js';
export declare class ScrabbleEventHandler implements IGameEventHandler {
    handleEvent(game: IGame, playerId: string, event: IClientEvent): EventResult;
    createStateUpdateEvent(game: IGame, playerId: string): IServerEvent;
    createErrorEvent(message: string): IServerEvent;
    private _handlePlayMove;
    private _handlePassTurn;
    private _handleExchangeTiles;
    /**
     * Convertit ScrabbleClassic vers le format GameState legacy
     */
    private _toGameState;
    /**
     * Applique un GameState sur une instance ScrabbleClassic
     */
    private _applyGameState;
    /**
     * Vérifie si la partie est terminée (chevalet vide + pioche vide)
     */
    private _checkGameOver;
    /**
     * Applique le calcul des scores de fin de partie (fin normale)
     */
    private _applyEndGameScoring;
    /**
     * Applique le calcul des scores de fin de partie (fin forcée - tous ont passé)
     */
    private _applyForcedEndGameScoring;
}
//# sourceMappingURL=ScrabbleEventHandler.d.ts.map