import GRDB

enum SchemaMigrator {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "favorite_albums") { table in
                table.primaryKey("albumID", .text)
                table.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "favorite_tracks") { table in
                table.primaryKey("trackID", .text)
                table.column("albumID", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "history") { table in
                table.primaryKey("trackID", .text)
                table.column("albumID", .text).notNull()
                table.column("title", .text).notNull()
                table.column("playedAt", .datetime).notNull().indexed()
            }

            try db.create(table: "playlists") { table in
                table.primaryKey("id", .text)
                table.column("name", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "playlist_items") { table in
                table.column("playlistID", .text).notNull().indexed()
                table.column("trackID", .text).notNull()
                table.column("albumID", .text).notNull()
                table.column("position", .integer).notNull()
                table.primaryKey(["playlistID", "trackID"])
            }
        }

        migrator.registerMigration("v2") { db in
            try db.alter(table: "favorite_albums") { table in
                table.add(column: "title", .text)
                table.add(column: "url", .text)
                table.add(column: "artworkURL", .text)
                table.add(column: "year", .integer)
                table.add(column: "albumType", .text)
            }

            try db.alter(table: "favorite_tracks") { table in
                table.add(column: "title", .text)
                table.add(column: "albumTitle", .text)
                table.add(column: "detailURL", .text)
                table.add(column: "albumURL", .text)
                table.add(column: "duration", .double)
            }
        }

        migrator.registerMigration("v3") { db in
            try db.alter(table: "favorite_albums") { table in
                table.add(column: "localArtworkURL", .text)
            }

            try db.alter(table: "favorite_tracks") { table in
                table.add(column: "artworkURL", .text)
                table.add(column: "localArtworkURL", .text)
            }
        }

        migrator.registerMigration("v4") { db in
            try db.create(table: "favorite_album_details") { table in
                table.primaryKey("albumID", .text)
                table.column("detailJSON", .text).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v5") { db in
            try db.alter(table: "history") { table in
                table.add(column: "albumTitle", .text)
                table.add(column: "detailURL", .text)
                table.add(column: "albumURL", .text)
                table.add(column: "artworkURL", .text)
                table.add(column: "duration", .double)
            }
        }

        return migrator
    }
}
