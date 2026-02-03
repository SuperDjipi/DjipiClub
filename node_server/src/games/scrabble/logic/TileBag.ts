import type { Tile } from '../models/GameModels.js';

// Configuration des tuiles en français
const TILE_DISTRIBUTION = {
    'A': { count: 9, points: 1 }, 'B': { count: 2, points: 3 },
    'C': { count: 2, points: 3 }, 'D': { count: 3, points: 2 },
    'E': { count: 15, points: 1 }, 'F': { count: 2, points: 4 },
    'G': { count: 2, points: 2 }, 'H': { count: 2, points: 4 },
    'I': { count: 8, points: 1 }, 'J': { count: 1, points: 8 },
    'K': { count: 1, points: 10 }, 'L': { count: 5, points: 1 },
    'M': { count: 3, points: 2 }, 'N': { count: 6, points: 1 },
    'O': { count: 6, points: 1 }, 'P': { count: 2, points: 3 },
    'Q': { count: 1, points: 8 }, 'R': { count: 6, points: 1 },
    'S': { count: 6, points: 1 }, 'T': { count: 6, points: 1 },
    'U': { count: 6, points: 1 }, 'V': { count: 2, points: 4 },
    'W': { count: 1, points: 10 }, 'X': { count: 1, points: 10 },
    'Y': { count: 1, points: 10 }, 'Z': { count: 1, points: 10 },
    '_': { count: 2, points: 0 } // Joker
};

/**
 * Crée une nouvelle pioche de tuiles, mélangée.
 */
export function createTileBag(): Tile[] {
    const bag: Tile[] = [];
    let idCounter = 0;

    for (const [letter, data] of Object.entries(TILE_DISTRIBUTION)) {
        for (let i = 0; i < data.count; i++) {
            bag.push({
                id: `tile-${idCounter++}`,
                letter: letter,
                points: data.points,
                isJoker: letter === '_',
                assignedLetter: null
            });
        }
    }
    // Pour tester le joker
    // [bag[0]!, bag[bag.length - 1]!] = [bag[bag.length - 1]!, bag[0]!];

    // Mélange de Fisher-Yates pour un mélange aléatoire efficace
    for (let i = bag.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [bag[i]!, bag[j]!] = [bag[j]!, bag[i]!];
    }

    console.log(`Pioche créée avec ${bag.length} tuiles.`);
    return bag;
}/**

 * Crée une nouvelle pioche de tuiles, mélangée.
 */
export function createTestBag(): Tile[] {
    const bag: Tile[] = [];
    let idCounter = 0;

    for (const [letter, data] of Object.entries(TILE_DISTRIBUTION)) {
        for (let i = 0; i < data.count; i++) {
            bag.push({
                id: `tile-${idCounter++}`,
                letter: letter,
                points: data.points,
                isJoker: letter === '_',
                assignedLetter: null
            });
        }
    }
    // Pour tester le joker
    // [bag[0] -> A
    [bag[1]!, bag[9]!] = [bag[9]!, bag[1]!];  // -> B
    [bag[2]!, bag[11]!] = [bag[11]!, bag[2]!]; // -> C
    [bag[3]!, bag[16]!] = [bag[16]!, bag[3]!]; // -> E
    [bag[4]!, bag[48]!] = [bag[48]!, bag[4]!]; // -> L
    [bag[5]!, bag[68]!] = [bag[68]!, bag[5]!]; // -> R
    [bag[6]!, bag[100]!] = [bag[100]!, bag[6]!]; // -> joker

    // Mélange de Fisher-Yates pour un mélange aléatoire efficace
    // for (let i = bag.length - 1; i > 7; i--) {
    //     const j = Math.floor(Math.random() * (i + 1));
    //     [bag[i]!, bag[j]!] = [bag[j]!, bag[i]!];
    // }

    console.log(`Pioche test créée avec ${bag.length} tuiles.`);
    return bag;
}

/**
 * Pioche des tuiles dans le sac.
 * @param bag La pioche actuelle.
 * @param count Le nombre de tuiles à piocher.
 * @returns Un objet contenant les tuiles piochées et la pioche mise à jour.
 */
export function drawTiles(bag: Tile[], count: number): { drawnTiles: Tile[], newBag: Tile[] } {
    const drawnTiles = bag.slice(0, count);
    const newBag = bag.slice(count);
    return { drawnTiles, newBag };
}

export function returnTilesToBag(bag: Tile[], tiles: Tile[]): Tile[] {
    return bag.concat(tiles);
}