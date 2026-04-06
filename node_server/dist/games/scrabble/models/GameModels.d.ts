import type { Player } from '../../../models/games/IGame.js';
import { GameStatus } from '../../../models/games/IGame.js';
export { GameStatus };
export type { Player };
export interface BoardPosition {
    row: number;
    col: number;
}
export interface Tile {
    id: string;
    letter: string;
    points: number;
    isJoker: boolean;
    assignedLetter?: string | null;
}
export interface PlacedTile {
    tile: Tile;
    boardPosition: BoardPosition;
}
export interface UserProfile {
    id: string;
    name: string;
    hashedPassword: string;
}
export interface ScrabblePlayer extends Player {
    rack: Tile[];
}
export interface BoardCell {
    boardPosition: BoardPosition;
    bonus: string;
    tile: Tile | null;
    isLocked?: boolean;
}
export type Board = BoardCell[][];
export interface Move {
    playerId: string;
    tiles: PlacedTile[];
    score: number;
    timestamp: number;
}
export declare enum Direction {
    HORIZONTAL = "HORIZONTAL",
    VERTICAL = "VERTICAL"
}
export interface FoundWord {
    text: string;
    direction: Direction;
    tiles: {
        tile: Tile;
        boardPosition: BoardPosition;
    }[];
    start: BoardPosition;
}
export interface GameState {
    id: string;
    hostId: string;
    board: Board;
    players: ScrabblePlayer[];
    tileBag: Tile[];
    status: GameStatus;
    placedPositions: BoardPosition[];
    turnNumber: number;
    currentPlayerIndex: number;
    forceEndGame: number;
}
//# sourceMappingURL=GameModels.d.ts.map