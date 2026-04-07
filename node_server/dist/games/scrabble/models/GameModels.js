import { GameStatus } from '../../../models/games/IGame.js';
// Re-export GameStatus et Player depuis IGame pour la rétrocompatibilité
export { GameStatus };
// Équivalent de la data class FoundWord (très utile pour la logique)
export var Direction;
(function (Direction) {
    Direction["HORIZONTAL"] = "HORIZONTAL";
    Direction["VERTICAL"] = "VERTICAL";
})(Direction || (Direction = {}));
//# sourceMappingURL=GameModels.js.map