import type { Tile } from '../models/GameModels.js';
/**
 * Crée une nouvelle pioche de tuiles, mélangée.
 */
export declare function createTileBag(): Tile[]; /**

 * Crée une nouvelle pioche de tuiles, mélangée.
 */
export declare function createTestBag(): Tile[];
/**
 * Pioche des tuiles dans le sac.
 * @param bag La pioche actuelle.
 * @param count Le nombre de tuiles à piocher.
 * @returns Un objet contenant les tuiles piochées et la pioche mise à jour.
 */
export declare function drawTiles(bag: Tile[], count: number): {
    drawnTiles: Tile[];
    newBag: Tile[];
};
export declare function returnTilesToBag(bag: Tile[], tiles: Tile[]): Tile[];
//# sourceMappingURL=TileBag.d.ts.map