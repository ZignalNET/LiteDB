//
//  Table.swift
//  Part of LiteDB. A thin IOS Swift wrapper around Sqlite3 database
//  Created by Emmanuel Adigun on 2022/05/24. emmanuel@zignal.net
//  Copyright © 2022 Zignal Systems. All rights reserved.
//

import Foundation
import SQLite3

protocol TableProtocol {
    func getTableName() -> String
    func setValue(_ value: Any?, forKey key: String)
}

open class Table: NSObject, TableProtocol {
    private var db: Database?
    open var tablename: String { return getTableName().lowercased() }
    
    public convenience init(db: Database?) {
        self.init()
        self.db = db
        self.checkTableStructure()
    }
    
    required public override init() {
        super.init()
    }
    
    open subscript(name: String) -> Any? {
        get {
            guard let column = getColumns().filter({ return $0.key == name || $0.value.name == name }).first else { return nil }
            return column.value.value
        }
        set(newElement) {
            if let column = getColumns().filter({$0.key == name || $0.value.name == name}).first { column.value.value = newElement}
        }
    }
    
    open func getDB() -> Database? { return self.db }
    
    open func getTableName() -> String {
        fatalError("Must be overriden in derived class ...")
    }
    
    open func rows<T: Table>(_ filter: String? = nil, _ callBack: RowCallback<T>?) throws {
        guard let db = db, db.isOpen() else { throw DatabaseError.databaseNotOpened("Database not opened") }
        do {
            let whereSql = filter != nil ? "WHERE \(filter!)" : ""
            let rows = try db.query("select * from \(tablename) \(whereSql)", nil, nil)
            let columns = getColumns()
            for row in rows {
                let t = type(of: self).init() as! T
                t.db = db // pass db pointer
                for ( key, column) in columns {
                    if let value = row[column.name] {
                        t.setValue(value, forKey: key)
                    }
                }
                callBack?(t as T)
            }
        }
        catch( let error ) {
            throw error
        }
    }
    
    open func rows<T: Table>() throws -> [T]
    {
        guard let db = db, db.isOpen() else { throw DatabaseError.databaseNotOpened("Database not opened") }
        var tablerows: [T] = [T]()
        do {
            let rows = try db.query("select * from \(tablename)", nil, nil)
            let columns = getColumns()
            for row in rows {
                let t = type(of: self).init() as! T
                t.db = db // pass db pointer
                for ( key, column) in columns {
                    if let value = row[column.name] {
                        t.setValue(value, forKey: key)
                    }
                }
                tablerows.append(t)
            }
        }
        catch( let error ) {
            throw error
        }
        return tablerows
    }
    
    open func insert() throws -> Int64 {
        guard let db = db, db.isOpen() else { throw DatabaseError.databaseNotOpened("Database not opened") }
        let sql = getInsertStatement()
        var lastrow: Int64 = 0
        do {
            try db.execute(sql, nil ) {rows,stats,error in
                if let s = stats, s.lastInsertedRowId != nil {
                    lastrow = s.lastInsertedRowId!
                    if let key = self.getKey() {
                        key.value = lastrow
                    }
                }
            }
        }
        catch( let error ) {
            throw error
        }
        return lastrow
    }
    
    open func update() throws -> Int32 {
        guard let db = db, db.isOpen() else { throw DatabaseError.databaseNotOpened("Database not opened") }
        var totalrows: Int32 = 0
        do {
            let sql = try getUpdateStatement()
            try db.execute(sql, nil ) {rows,stats,error in
                if let s = stats, s.totalRowsAffected != nil {
                    totalrows = s.totalRowsAffected!
                }
            }
        }
        catch( let error ) {
            throw error
        }
        return totalrows
    }
    
    open func delete() throws -> Int32 {
        guard let db = db, db.isOpen() else { throw DatabaseError.databaseNotOpened("Database not opened") }
        guard let key = getKey() else { throw DatabaseError.noPrimaryKey("Cannot delete. No primary key defined in [\(tablename)]") }
        guard let value = key.value else { throw DatabaseError.noPrimaryKey("Cannot delete. Primary key '\(key.name)' defined in '\(tablename)' is nil") }
        var totalrows: Int32 = 0
        do {
            let sql = "DELETE FROM \(tablename) where \(key.name) = \(value)"
            try db.execute(sql, nil ) {rows,stats,error in
                if let s = stats, s.totalRowsAffected != nil {
                    totalrows = s.totalRowsAffected!
                }
            }
        }
        catch( let error ) {
            throw error
        }
        return totalrows
    }
    
    private func checkTableStructure() {
        do {
            if try self.tableExists() == false {
                try db?.execute(getCreateStatement(), nil, { rows, stats, error in
                    if let stats = stats, stats.result == SQLITE_DONE {
                        print("Table \(self.tablename) successfully created ...")
                    }
                })
            }
            else { print("Table \(self.tablename) already created ...") }
        }
        catch( let error ) {
            print( error )
        }
    }
    
    private func tableExists(_ tableName: String? = nil) throws -> Bool {
        guard let db = db, db.isOpen() else { throw DatabaseError.databaseNotOpened("Database not opened") }
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) = ?"
        var exists = false
        do {
            var params: QueryParameters?
            if let table = tableName { params = [table.lowercased()] }
            else { params = [self.tablename] }
            let rows = try db.query(sql, params!, nil )
            exists = rows.count > 0
        }
        catch( let error ) {
            throw error
        }
        return exists
    }
    
    private func getColumns() -> TableColumns {
        var columns = TableColumns()
        for (_, attr) in Mirror(reflecting:self).children.enumerated() {
            if let name = attr.label, let column = attr.value as? Column {
                columns[name] = column
            }
        }
        return columns
    }
    
    private func getKey() -> Column? {
        guard let column = getColumns().filter({ $0.value.isPrimaryKey() }).first else { return nil }
        return column.value
    }
    
    private func getKey(key: String) -> Column? {
        guard let column = getColumns().filter({ $0.key == key }).first else { return nil }
        return column.value
    }
    
    open override func value(forKey key: String) -> Any? {
        if let value = getKey(key: key) { return value }
        else { return super.value(forKey: key) } // Maybe in super class !!
    }
    
    open override func setValue(_ value: Any?, forKey key: String) {
        guard let column = getKey(key: key) else { return }
        column.value = value
    }
    
    private func getCreateStatement() -> String {
        var sql = " CREATE TABLE \(tablename) ( "
        var i = 0
        let columns = getColumns().sorted { a,b in return a.key < b.key } // ascending order ...
        for column in columns {
            let field = column.value
            sql += field.type.getMetaInfo(field: field)
            if i < columns.count - 1 { sql += "," }
            i += 1
        }
        sql += " )"
        return sql
    }
    
    private func getInsertStatement() -> String{
        var fields = "( "
        var values = "( "
        var i = 0
        let columns = getColumns().sorted { a,b in return a.key < b.key } // ascending order ...
        for column in columns {
            let field = column.value
            fields += field.name
            if field.isAutoIncrement() { field.value = nil } //clear out whatever ...
            if let v = field.value {
                if field.type.type == SQLITE_TEXT  { values += "'\(v)'" }
                else if field.type.type == SQLITE_DATE ||
                    field.type.type == SQLITE_DATETIME {
                    if v is Date {
                        values += "'\(Database.databaseDateFormatter.string(from: v as! Date))'"
                    }
                    else { values += "'\(v)'" }
                }
                else { values += "\(v)" }
            }
            else {
                if let dv = column.value.default_value {values += "\(dv)" }
                else { values += "NULL" }
            }
            
            if i < columns.count - 1 {
                fields += ","
                values += ","
            }
            i += 1
        }
        
        fields += " )"
        values += " )"
        return " INSERT INTO \(tablename) \(fields) VALUES \(values) "
    }
    
    private func getUpdateStatement() throws -> String {
        var sql = ""
        let columns = getColumns().sorted { a,b in return a.key < b.key } // ascending order ...
        var i = 0
        for column in columns {
            let field = column.value
            sql += "\(field.name) = "
            if let v = field.value {
                if field.type.type == SQLITE_TEXT  { sql += "'\(v)'" }
                else if field.type.type == SQLITE_DATE ||
                    field.type.type == SQLITE_DATETIME {
                    if v is Date {
                        sql += "'\(Database.databaseDateFormatter.string(from: v as! Date))'"
                    }
                    else { sql += "'\(v)'" }
                }
                else { sql += "\(v)" }
            }
            else {
                if let dv = column.value.default_value {sql += "\(dv)" }
                else { sql += "NULL" }
            }
            
            if i < columns.count - 1 { sql += "," }
            i += 1
        }
        
        if let key = getKey(), let value = key.value {
            return "UPDATE \(tablename) SET \(sql) where  \(key.name) = \(value)"
        }
        else if let key = getKey(), key.value == nil {
            throw DatabaseError.noPrimaryKey("Cannot update. Primary key \(key.name) is nil in [\(tablename)]")
        }
        else { throw DatabaseError.noPrimaryKey("Cannot update. No primary key defined in [\(tablename)]") }
    }
    
}

