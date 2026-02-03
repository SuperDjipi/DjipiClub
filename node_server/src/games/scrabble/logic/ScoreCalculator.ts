// Dans src/logic/ScoreCalculator.ts

import type { Board, FoundWord, BoardPosition, Tile } from '../models/GameModels.js';

const letterPoints: { [key: string]: number } = {
    'A': 1, 'B': 3, 'C': 3, 'D': 2, 'E': 1, 'F': 4,
    'G': 2, 'H': 4, 'I': 1, 'J': 8, 'K': 10, 'L': 1,
    'M': 2, 'N': 1, 'O': 1, 'P': 3, 'Q': 8, 'R': 1, 'S': 1,
    'T': 1, 'U': 1, 'V': 4, 'W': 10, 'X': 10, 'Y': 10, 'Z': 10, '_': 0
};

function getBonus(board: Board, pos: BoardPosition): string {
    return board[pos.row]?.[pos.col]?.bonus ?? 'NONE';
}

function calculateWordScore(
    word: FoundWord,
    board: Board,
    newlyPlacedPositions: BoardPosition[]
): number {
    let wordScore = 0;
    let wordMultiplier = 1;
    const newPosSet = new Set(newlyPlacedPositions.map(p => `${p.row},${p.col}`));
    
    // On parcourt chaque tuile du mot trouvé
    for (const { tile, boardPosition } of word.tiles) {
        // La tuile que l'on est en train de traiter vient-elle d'être posée ?
        const isNewTile = newPosSet.has(`${boardPosition.row},${boardPosition.col}`);

        let letterScore = tile.points;

        // Le bonus d'une case ne s'applique QUE si la tuile vient d'être posée dessus.
        if (isNewTile) {
            const bonus = getBonus(board, boardPosition);
            switch (bonus) {
                case "DOUBLE_LETTER":
                    letterScore *= 2;
                    break;
                case "TRIPLE_LETTER":
                    letterScore *= 3;
                    break;
                case "DOUBLE_WORD":
                case "CENTER": // La case centrale est un mot compte double
                    wordMultiplier *= 2;
                    break;
                case "TRIPLE_WORD":
                    wordMultiplier *= 3;
                    break;
            }
        }

        // On ajoute le score de la lettre (avec son bonus éventuel) au score total du mot
        wordScore += letterScore;
    }

    return wordScore * wordMultiplier;
}

export function calculateTotalScore(
    foundWords: Set<FoundWord>,
    board: Board,
    newlyPlacedPositions: BoardPosition[]
): number {
    let totalScore = 0;
    for (const word of foundWords) {
        totalScore += calculateWordScore(word, board, newlyPlacedPositions);
    }
    const bonusScrabble = newlyPlacedPositions.length === 7 ? 50 : 0;
    return totalScore + bonusScrabble;
}

