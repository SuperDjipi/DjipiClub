import type { Board, BoardPosition, Tile, FoundWord } from '../models/GameModels.js';
import { Direction } from '../models/GameModels.js';

const BOARD_SIZE = 15;

function getTile(board: Board, boardPosition: BoardPosition): Tile | null {
    if (boardPosition.row >= 0 && boardPosition.row < BOARD_SIZE && boardPosition.col >= 0 && boardPosition.col < BOARD_SIZE) {
        return board[boardPosition.row]![boardPosition.col]!.tile;
    }
    return null;
}

/**
 * Retourne la lettre à utiliser pour la validation d'un mot.
 * Gère le cas du joker.
 */
function getDisplayLetter(tile: Tile): string {
    // Si c'est un joker avec une lettre assignée, on utilise cette lettre.
    // Sinon, on utilise la lettre de base de la tuile.
    return tile.isJoker && tile.assignedLetter ? tile.assignedLetter : tile.letter;
}
// ----------------------------------------

export function findHorizontalWord(board: Board, startPos: BoardPosition): FoundWord | null {
    if (getTile(board, startPos) === null) {
        return null;
    }

    const row = startPos.row;

    // 1. Trouver la colonne de début
    let startIndex = startPos.col;
    while (startIndex > 0 && getTile(board, { row, col: startIndex - 1 }) !== null) {
        startIndex--;
    }

    // 2. Trouver la colonne de fin
    let endIndex = startPos.col;
    while (endIndex < BOARD_SIZE - 1 && getTile(board, { row, col: endIndex + 1 }) !== null) {
        endIndex++;
    }

    if (startIndex === endIndex) {
        return null; // Mot d'une seule lettre, non connecté
    }

    // 3. Construire le mot
    let wordText = "";
    // On doit aussi garder une trace des tuiles et de la position de départ
    const wordTiles: { tile: Tile, boardPosition: BoardPosition }[] = [];
    const startOfWordPos: BoardPosition = { row, col: startIndex };
    for (let col = startIndex; col <= endIndex; col++) {
        const tile = getTile(board, { row, col });
        if (!tile) return null; // Sécurité
        wordText += getDisplayLetter(tile);
        wordTiles.push({ tile, boardPosition: { row, col } });
    }

    return { text: wordText, tiles: wordTiles, direction: Direction.HORIZONTAL, start: startOfWordPos };
}

export function findVerticalWord(board: Board, startPos: BoardPosition): FoundWord | null {
    if (getTile(board, startPos) === null) {
        return null;
    }

    const col = startPos.col;

    // 1. Trouver la ligne de début (en remontant)
    let startIndex = startPos.row;
    while (startIndex > 0 && getTile(board, { row: startIndex - 1, col }) !== null) {
        startIndex--;
    }

    // 2. Trouver la ligne de fin (en descendant)
    let endIndex = startPos.row;
    while (endIndex < BOARD_SIZE - 1 && getTile(board, { row: endIndex + 1, col }) !== null) {
        endIndex++;
    }

    if (startIndex === endIndex) {
        return null;
    }

    // 3. Construire le mot
    let wordText = "";
    // On doit aussi garder une trace des tuiles et de la position de départ
    const wordTiles: { tile: Tile, boardPosition: BoardPosition }[] = [];
    const startOfWordPos: BoardPosition = { row: startIndex , col};
    for (let row = startIndex; row <= endIndex; row++) {
        const tile = getTile(board, { row, col });
        if (!tile) return null;
        wordText += getDisplayLetter(tile);
        wordTiles.push({ tile, boardPosition: { row, col } });
    }

    return { text: wordText, tiles: wordTiles, direction: Direction.VERTICAL, start: startOfWordPos };
}

export function findAllWordsFormedByMove(board: Board, placedTiles: { boardPosition: BoardPosition, tile: Tile }[]): Set<FoundWord> {
    if (placedTiles.length === 0) {
        return new Set();
    }

    // On utilise une Map pour stocker les mots trouvés, avec une clé unique.
    const foundWordsMap = new Map<string, FoundWord>();

    for (const placed of placedTiles) {
        const hWord = findHorizontalWord(board, placed.boardPosition);
        if (hWord) {
            // On crée une clé unique : ex: "MOT_HORIZONTAL_7_5"
            const key = `${hWord.text}_${hWord.direction}_${hWord.start.row}_${hWord.start.col}`;
            foundWordsMap.set(key, hWord);
        }

        const vWord = findVerticalWord(board, placed.boardPosition);
        if (vWord) {
            // Clé unique pour le mot vertical
            const key = `${vWord.text}_${vWord.direction}_${vWord.start.row}_${vWord.start.col}`;
            foundWordsMap.set(key, vWord);
        }
    }
    // On retourne un Set contenant uniquement les valeurs de la Map, ce qui garantit l'unicité.
    return new Set(foundWordsMap.values());
}