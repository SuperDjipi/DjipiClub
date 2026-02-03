// On importe 'fs' (File System) et 'path', des modules natifs de Node.js pour lire les fichiers.
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';import { dirname } from 'path';

console.log("Initialisation du module Dictionnaire...");

// On utilise une Map où la clé est la longueur du mot et la valeur est un Set de mots.
// C'est l'équivalent exact de votre Map<Int, Set<String>> en Kotlin.
const wordsByLength: Map<number, Set<string>> = new Map();

/**
 * Fonction qui charge tous les fichiers de dictionnaire en mémoire.
 * Elle est appelée une seule fois au démarrage du serveur.
 */
function loadDictionaries(): void {

    const __filename = fileURLToPath(import.meta.url);
    const __dirname = dirname(__filename);
    const dicoPath = path.join(__dirname, '..', '..', 'dico'); // Chemin vers le dossier 'dico'
    console.log(`Chargement des dictionnaires depuis : ${dicoPath}`);

    try {
        for (let length = 2; length <= 15; length++) {
            let fileName = '';
            switch (length) {
                case 2: fileName = 'deux'; break;
                case 3: fileName = 'trois'; break;
                case 4: fileName = 'quatre'; break;
                case 5: fileName = 'cinq'; break;
                case 6: fileName = 'six'; break;
                case 7: fileName = 'sept'; break;
                case 8: fileName = 'huit'; break;
                case 9: fileName = 'neuf'; break;
                case 10: fileName = 'dix'; break;
                case 11: fileName = 'onze'; break;
                case 12: fileName = 'douze'; break;
                case 13: fileName = 'treize'; break;
                case 14: fileName = 'quatorze'; break;
                case 15: fileName = 'quinze'; break;
            }

            if (fileName) {
                const filePath = path.join(dicoPath, `${fileName}.txt`);
                // On lit le contenu du fichier (une seule longue ligne de mots séparés par des virgules)
                const fileContent = fs.readFileSync(filePath, 'utf-8');

                // On découpe la chaîne, on nettoie chaque mot et on crée un Set pour une recherche rapide.
                const wordSet = new Set(
                    fileContent.split(',').map(word => word.trim().toLowerCase())
                );

                wordsByLength.set(length, wordSet);
                console.log(`   - ${fileName}.txt chargé (${wordSet.size} mots)`);
            }
        }
        console.log("✅ Dictionnaires chargés avec succès.");
    } catch (error) {
        console.error("❌ ERREUR FATALE : Impossible de charger les fichiers du dictionnaire.", error);
        process.exit(1); // On arrête le serveur si les dictionnaires ne peuvent pas être chargés.
    }
}

/**
 * Vérifie si un mot est valide en se basant sur les dictionnaires chargés.
 * @param word Le mot à vérifier (la casse est ignorée).
 * @returns true si le mot est valide, false sinon.
 */
export function isWordValid(word: string): boolean {
    const length = word.length;
    const wordToCheck = word.toLowerCase();

    // On récupère le Set de mots pour la bonne longueur
    const wordSet = wordsByLength.get(length);

    // On vérifie si le mot existe dans le Set.
    // La recherche dans un Set est extrêmement rapide (O(1) en moyenne).
    return wordSet ? wordSet.has(wordToCheck) : false;
}

// --- Point d'entrée du module ---
// On appelle la fonction de chargement une seule fois, au moment où ce fichier est importé.
loadDictionaries();