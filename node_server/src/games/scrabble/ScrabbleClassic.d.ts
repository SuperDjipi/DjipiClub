import { BaseGame } from '../../models/games/BaseGame.js';
import { GameType, type Player, type MoveResult } from '../../models/games/IGame.js';
import type { Tile, Board, BoardPosition, ScrabblePlayer } from './models/GameModels.js';
export declare class ScrabbleClassic extends BaseGame {
    type: GameType;
    minPlayers: number;
    maxPlayers: number;
    players: ScrabblePlayer[];
    board: Board;
    tileBag: Tile[];
    placedPositions: BoardPosition[];
    forceEndGame: number;
    constructor(id: string, hostId: string);
    start(): void;
    handleMove(playerId: string, move: any): MoveResult;
    passTurn(playerId: string): void;
    getStateForPlayer(playerId: string): any;
    /**
     * Retourne un joueur Scrabble avec son chevalet
     */
    getScrabblePlayer(playerId: string): ScrabblePlayer | undefined;
    private _applyMove;
    private _nextPlayer;
    /**
     * Ajoute un joueur avec un chevalet vide (sera rempli au démarrage)
     */
    addPlayer(player: Player): boolean;
}
//# sourceMappingURL=ScrabbleClassic.d.ts.map