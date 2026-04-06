/**
 * Gestionnaire d'événements pour le jeu Scrabble.
 * Encapsule toute la logique de traitement des événements WebSocket spécifiques au Scrabble.
 */
import { GameStatus } from '../../models/games/IGame.js';
import { processPlayMove, processExchangeTiles } from './logic/GameEngine.js';
export class ScrabbleEventHandler {
    handleEvent(game, playerId, event) {
        // Cast vers ScrabbleClassic pour accéder aux propriétés spécifiques
        const scrabbleGame = game;
        switch (event.type) {
            case 'PLAY_MOVE':
                return this._handlePlayMove(scrabbleGame, playerId, event.payload?.placedTiles || []);
            case 'PASS_TURN':
                return this._handlePassTurn(scrabbleGame, playerId);
            case 'EXCHANGE_TILES':
                return this._handleExchangeTiles(scrabbleGame, playerId, event.payload?.tilesToExchange || []);
            default:
                return {
                    success: false,
                    error: `Type d'événement inconnu: ${event.type}`
                };
        }
    }
    createStateUpdateEvent(game, playerId) {
        const stateForPlayer = game.getStateForPlayer(playerId);
        return {
            type: 'GAME_STATE_UPDATE',
            payload: stateForPlayer
        };
    }
    createErrorEvent(message) {
        return {
            type: 'ERROR',
            payload: { message }
        };
    }
    // ========================================================================
    // MÉTHODES PRIVÉES DE TRAITEMENT DES ÉVÉNEMENTS
    // ========================================================================
    _handlePlayMove(game, playerId, placedTiles) {
        // Vérifier que c'est le tour du joueur
        if (!game.isPlayerTurn(playerId)) {
            return {
                success: false,
                error: "Ce n'est pas votre tour"
            };
        }
        // Convertir ScrabbleClassic vers le format GameState attendu par processPlayMove
        const gameState = this._toGameState(game);
        // Déléguer au moteur de jeu
        const nextGameState = processPlayMove(gameState, placedTiles);
        if (!nextGameState) {
            return {
                success: false,
                error: "Votre coup est invalide."
            };
        }
        // Appliquer les modifications au jeu
        this._applyGameState(game, nextGameState);
        // Vérifier fin de partie
        const isGameOver = this._checkGameOver(game, playerId);
        if (isGameOver) {
            this._applyEndGameScoring(game, playerId);
        }
        console.log(`✅ Coup validé pour ${playerId}!`);
        return {
            success: true,
            updatedGame: game,
            shouldBroadcast: true,
            isGameOver
        };
    }
    _handlePassTurn(game, playerId) {
        // Vérifier que c'est le tour du joueur
        if (!game.isPlayerTurn(playerId)) {
            return {
                success: false,
                error: "Ce n'est pas votre tour"
            };
        }
        console.log(`➡️  Le joueur ${playerId} a passé son tour.`);
        // Incrémenter le compteur de fin forcée
        game.forceEndGame++;
        game.placedPositions = [];
        // Passer au joueur suivant
        game.currentPlayerIndex = (game.currentPlayerIndex + 1) % game.players.length;
        game.turnNumber++;
        // Vérifier fin de partie forcée (tous les joueurs ont passé)
        const isGameOver = game.forceEndGame > game.players.length;
        if (isGameOver) {
            this._applyForcedEndGameScoring(game);
        }
        return {
            success: true,
            updatedGame: game,
            shouldBroadcast: true,
            isGameOver
        };
    }
    _handleExchangeTiles(game, playerId, tilesToExchange) {
        // Vérifier que c'est le tour du joueur
        if (!game.isPlayerTurn(playerId)) {
            return {
                success: false,
                error: "Ce n'est pas votre tour"
            };
        }
        const player = game.getPlayer(playerId);
        if (!player) {
            return {
                success: false,
                error: "Joueur non trouvé"
            };
        }
        // Convertir vers GameState et utiliser processExchangeTiles
        const gameState = this._toGameState(game);
        const scrabblePlayer = gameState.players.find(p => p.id === playerId);
        if (!scrabblePlayer) {
            return {
                success: false,
                error: "Joueur non trouvé dans l'état"
            };
        }
        const updatedState = processExchangeTiles(gameState, scrabblePlayer, tilesToExchange);
        this._applyGameState(game, updatedState);
        return {
            success: true,
            updatedGame: game,
            shouldBroadcast: true
        };
    }
    // ========================================================================
    // MÉTHODES UTILITAIRES
    // ========================================================================
    /**
     * Convertit ScrabbleClassic vers le format GameState legacy
     */
    _toGameState(game) {
        return {
            id: game.id,
            hostId: game.hostId,
            board: game.board,
            players: game.players,
            tileBag: game.tileBag,
            status: game.status,
            placedPositions: game.placedPositions,
            turnNumber: game.turnNumber,
            currentPlayerIndex: game.currentPlayerIndex,
            forceEndGame: game.forceEndGame
        };
    }
    /**
     * Applique un GameState sur une instance ScrabbleClassic
     */
    _applyGameState(game, state) {
        game.board = state.board;
        game.players = state.players;
        game.tileBag = state.tileBag;
        game.status = state.status;
        game.placedPositions = state.placedPositions;
        game.turnNumber = state.turnNumber;
        game.currentPlayerIndex = state.currentPlayerIndex;
        game.forceEndGame = state.forceEndGame;
    }
    /**
     * Vérifie si la partie est terminée (chevalet vide + pioche vide)
     */
    _checkGameOver(game, playerId) {
        const player = game.getPlayer(playerId);
        return !!player && player.rack.length === 0 && game.tileBag.length === 0;
    }
    /**
     * Applique le calcul des scores de fin de partie (fin normale)
     */
    _applyEndGameScoring(game, winningPlayerId) {
        console.log(`🏁 La partie ${game.id} est terminée ! Calcul du score final.`);
        // Calculer les points restants dans les chevalets adverses
        let remainingPoints = 0;
        game.players.forEach(p => {
            if (p.id !== winningPlayerId) {
                p.rack.forEach(tile => {
                    remainingPoints += tile.points;
                });
            }
        });
        // Mettre à jour les scores finaux
        game.players = game.players.map(p => {
            if (p.id === winningPlayerId) {
                return { ...p, score: p.score + remainingPoints };
            }
            else {
                let playerRemainingPoints = 0;
                p.rack.forEach(tile => {
                    playerRemainingPoints += tile.points;
                });
                return { ...p, score: p.score - playerRemainingPoints };
            }
        });
        game.status = GameStatus.FINISHED;
    }
    /**
     * Applique le calcul des scores de fin de partie (fin forcée - tous ont passé)
     */
    _applyForcedEndGameScoring(game) {
        console.log(`🏁 La partie ${game.id} est terminée (fin forcée) ! Calcul du score final.`);
        // Soustraire les points restants de chaque joueur
        game.players = game.players.map(p => {
            let playerRemainingPoints = 0;
            p.rack.forEach(tile => {
                playerRemainingPoints += tile.points;
            });
            return { ...p, score: p.score - playerRemainingPoints };
        });
        game.status = GameStatus.FINISHED;
    }
}
//# sourceMappingURL=ScrabbleEventHandler.js.map