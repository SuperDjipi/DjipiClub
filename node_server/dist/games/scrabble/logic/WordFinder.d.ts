import type { Board, BoardPosition, Tile, FoundWord } from '../models/GameModels.js';
export declare function findHorizontalWord(board: Board, startPos: BoardPosition): FoundWord | null;
export declare function findVerticalWord(board: Board, startPos: BoardPosition): FoundWord | null;
export declare function findAllWordsFormedByMove(board: Board, placedTiles: {
    boardPosition: BoardPosition;
    tile: Tile;
}[]): Set<FoundWord>;
//# sourceMappingURL=WordFinder.d.ts.map