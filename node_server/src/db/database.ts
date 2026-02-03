    // Fichier: src/db/database.ts

    import { open } from 'sqlite';
    import sqlite3 from 'sqlite3';
    import type { UserProfile } from '../games/scrabble/models/GameModels.js'; // Nous déplacerons UserProfile

    // On définit le chemin vers notre fichier de base de données.
    const DB_FILE = './lebarcs.sqlite';

    // On encapsule notre connexion dans une fonction asynchrone
    // pour s'assurer que la table est bien créée avant que le serveur ne l'utilise.
    export async function initializeDatabase() {
        // On ouvre la connexion à la base de données.
        // Le fichier sera créé s'il n'existe pas.
        const db = await open({
            filename: DB_FILE,
            driver: sqlite3.Database
        });

        // On exécute la commande SQL pour créer la table des utilisateurs,
        // mais seulement si elle n'existe pas déjà (IF NOT EXISTS).
        await db.exec(`
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                hashedPassword TEXT NOT NULL
            );
        `);
        await db.exec(`
            CREATE TABLE IF NOT EXISTS games (
                id TEXT PRIMARY KEY,
                gameState TEXT NOT NULL,
                status TEXT NOT NULL,
                lastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);
        // Index sur status (séparé du CREATE TABLE)
        await db.exec(`
            CREATE INDEX IF NOT EXISTS idx_games_status ON games(status)
        `);
        console.log("🗄️  Base de données DjipiClub initialisée.");

        // On retourne l'objet 'db' pour pouvoir l'utiliser ailleurs.
        return db;
    }
    
