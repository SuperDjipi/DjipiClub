import { type IGame, GameType, GameStatus } from '../models/games/IGame.js';
import type { IGameEventHandler } from '../models/games/IGameEvents.js';
import { ScrabbleClassic } from './scrabble/ScrabbleClassic.js';
import { ScrabbleEventHandler } from './scrabble/ScrabbleEventHandler.js';
// import { ScrabbleDuplicate } from './scrabble/ScrabbleDuplicate.js'; // Plus tard
// import { BoggleGame } from './boggle/BoggleGame.js'; // Plus tard
// import { YamGame } from './yam/YamGame.js'; // Plus tard

// Cache des handlers (singleton par type de jeu)
const eventHandlers = new Map<GameType, IGameEventHandler>();

export class GameFactory {
    static createGame(type: GameType, gameId: string, hostId: string): IGame {
        switch (type) {
            case GameType.SCRABBLE_CLASSIC:
                return new ScrabbleClassic(gameId, hostId);

            case GameType.SCRABBLE_DUPLICATE:
                throw new Error('Scrabble Duplicate pas encore implémenté');

            case GameType.BOGGLE:
                throw new Error('Boggle pas encore implémenté');

            case GameType.YAM:
                throw new Error('Yam pas encore implémenté');

            case GameType.DAMES:
                throw new Error('Dames pas encore implémenté');

            case GameType.TICTACJONGH:
                throw new Error('TicTacJongh est solo uniquement');

            default:
                throw new Error(`Type de jeu inconnu: ${type}`);
        }
    }

    /**
     * Retourne le gestionnaire d'événements pour un type de jeu donné.
     * Les handlers sont des singletons (une instance par type).
     */
    static getEventHandler(type: GameType): IGameEventHandler {
        let handler = eventHandlers.get(type);

        if (!handler) {
            switch (type) {
                case GameType.SCRABBLE_CLASSIC:
                    handler = new ScrabbleEventHandler();
                    break;

                case GameType.SCRABBLE_DUPLICATE:
                    throw new Error('Scrabble Duplicate pas encore implémenté');

                case GameType.BOGGLE:
                    throw new Error('Boggle pas encore implémenté');

                case GameType.YAM:
                    throw new Error('Yam pas encore implémenté');

                default:
                    throw new Error(`Pas de handler pour le type: ${type}`);
            }

            eventHandlers.set(type, handler);
        }

        return handler;
    }

    /**
     * Désérialise une partie depuis sa représentation JSON.
     * Utilisé pour recharger les parties depuis la base de données.
     */
    static deserializeGame(jsonData: string): IGame {
        const data = JSON.parse(jsonData);

        // Déterminer le type de jeu
        const gameType = data.type as GameType;

        if (!gameType) {
            // Rétrocompatibilité : si pas de type, c'est du Scrabble Classic
            return this._deserializeScrabbleClassic(data);
        }

        switch (gameType) {
            case GameType.SCRABBLE_CLASSIC:
                return this._deserializeScrabbleClassic(data);

            case GameType.SCRABBLE_DUPLICATE:
                throw new Error('Scrabble Duplicate pas encore implémenté');

            case GameType.BOGGLE:
                throw new Error('Boggle pas encore implémenté');

            case GameType.YAM:
                throw new Error('Yam pas encore implémenté');

            default:
                throw new Error(`Type de jeu inconnu pour désérialisation: ${gameType}`);
        }
    }

    /**
     * Désérialise une partie Scrabble Classic
     */
    private static _deserializeScrabbleClassic(data: any): ScrabbleClassic {
        const game = new ScrabbleClassic(data.id, data.hostId);

        // Restaurer l'état
        game.players = data.players || [];
        game.status = data.status || GameStatus.WAITING_FOR_PLAYERS;
        game.currentPlayerIndex = data.currentPlayerIndex || 0;
        game.turnNumber = data.turnNumber || 0;

        // État spécifique Scrabble
        game.board = data.board;
        game.tileBag = data.tileBag || [];
        game.placedPositions = data.placedPositions || [];
        game.forceEndGame = data.forceEndGame || 0;

        return game;
    }

    static getSupportedGames(): GameType[] {
        return [
            GameType.SCRABBLE_CLASSIC,
            // Autres seront ajoutés progressivement
        ];
    }

    static getGameInfo(type: GameType): { name: string, minPlayers: number, maxPlayers: number } {
        switch (type) {
            case GameType.SCRABBLE_CLASSIC:
                return { name: 'Scrabble Classique', minPlayers: 2, maxPlayers: 4 };
            case GameType.SCRABBLE_DUPLICATE:
                return { name: 'Scrabble Duplicate', minPlayers: 2, maxPlayers: 20 };
            case GameType.BOGGLE:
                return { name: 'Boggle', minPlayers: 2, maxPlayers: 8 };
            case GameType.YAM:
                return { name: 'Yam', minPlayers: 2, maxPlayers: 6 };
            default:
                return { name: 'Inconnu', minPlayers: 2, maxPlayers: 4 };
        }
    }
}