import type { Board, BoardPosition, Tile } from "./GameModels.js";


// --- Fonctions utilitaires pour le plateau ---
const BOARD_SIZE = 15;
function determineBonusType(row: number, col: number): string {
    // Le centre est spécial (techniquement aussi un DOUBLE_WORD)
    if (row === 7 && col === 7) return "CENTER";

    // Mot Compte Triple (TRIPLE_WORD) - les cases rouges
    const tripleWordSpots = [
        "0,0", "0,7", "0,14",
        "7,0", "7,14",
        "14,0", "14,7", "14,14"
    ];
    if (tripleWordSpots.includes(`${row},${col}`)) {
        return "TRIPLE_WORD";
    }

    // Mot Compte Double (DOUBLE_WORD) - les cases roses
    const doubleWordSpots = [
        "1,1", "1,13", "2,2", "2,12", "3,3", "3,11", "4,4", "4,10",
        "10,4", "10,10", "11,3", "11,11", "12,2", "12,12", "13,1", "13,13"
    ];
    if (doubleWordSpots.includes(`${row},${col}`)) {
        return "DOUBLE_WORD";
    }

    // Lettre Compte Triple (TRIPLE_LETTER) - les cases bleu foncé
    const tripleLetterSpots = [
        "1,5", "1,9", "5,1", "5,5", "5,9", "5,13",
        "9,1", "9,5", "9,9", "9,13", "13,5", "13,9"
    ];
    if (tripleLetterSpots.includes(`${row},${col}`)) {
        return "TRIPLE_LETTER";
    }

    // Lettre Compte Double (DOUBLE_LETTER) - les cases bleu clair
    const doubleLetterSpots = [
        "0,3", "0,11", "2,6", "2,8", "3,0", "3,7", "3,14",
        "6,2", "6,6", "6,8", "6,12", "7,3", "7,11",
        "8,2", "8,6", "8,8", "8,12", "11,0", "11,7", "11,14",
        "12,6", "12,8", "14,3", "14,11"
    ];
    if (doubleLetterSpots.includes(`${row},${col}`)) {
        return "DOUBLE_LETTER";
    }

    return "NONE";
}
export function createEmptyBoard(): Board {
    return Array.from({ length: BOARD_SIZE }, (_, row) => Array.from({ length: BOARD_SIZE }, (_, col) => ({
        boardPosition: { row, col },
        bonus: determineBonusType(row, col),
        tile: null,
        isLocked: false
    }))
    );
}
export function createNewBoard(originalBoard: Board, placedTiles: { boardPosition: BoardPosition; tile: Tile; }[]): Board {
    // Crée une copie profonde du plateau pour ne pas modifier l'original
    const newBoard = JSON.parse(JSON.stringify(originalBoard));
    for (const { boardPosition, tile } of placedTiles) {
        newBoard[boardPosition.row][boardPosition.col].tile = tile;
    }
    return newBoard;
}
