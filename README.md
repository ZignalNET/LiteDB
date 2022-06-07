# LiteDB

LiteDb is a thin IOS `Swift` wrapper around `SQLITE3` database.


## Usage

```
import LiteDB

//Define your Table
class Contacts: Table {
    
    let id     = Column(name: "c_uid", primary_key: true, auto_increment: true)
    let name   = Column(name: "c_name")
    let period = Column(name: "c_period", type: .DATETIME/*, default_value: "CURRENT_TIMESTAMP"*/)
    let total  = Column(name: "c_total", type: .DECIMAL/*, default_value: 78.5632*/)
    
    override var tablename: String { return "c_contacts" }
}
```

##Create you sqlite3 database 
```
let db = Database.sharedInstance("mydatabase.sqlite3")
```

###Test whether its opened
```
if db.isOpen() {
    do {
        let c = Contacts(db: db)
        c["name"] = "John Doe"
        c["period"] = DateTime()
        c["total"] = 120.78
        
        
        //Lets insert 
        let lastrowinserted = try c.insert()
        // c["id"] now contains lastrowinserted
        
        //And update "name" column
        c["name"] = "John Doe 2"
        let totalrowsupdated = try c.update()
        
        try db.close();
        try db.remove()
    }
    catch( let error ) {
        print(error)
    }
}
```

###Fetch records ..
```
if db.isOpen() {
    do {
        let c = Contacts(db: db)
        //Fetch all rows
        for row in (try c.rows()) {
                print( row["id"]!,row["name"]!, row["period"]!, row["total"]! )
        }
        
        //fetch where c_uid = 2
        try c.rows("c_uid = 2"){ (row) in  //actual table column name NOT swift variable name
            print( row["id"]!, row["name"]!, row["period"]!, row["total"]! )
        }
        
        //Count of rows
        print("Total rows via table = \(c.count) ")
            
        try db.close();
        try db.remove()
    }
    catch( let error ) {
        print(error)
    }
}
```

###You can also access your sqlite3 database via raw SQL; its your choice!

```
if db.isOpen() {
    do {
        
        try db.execute("create table IF NOT EXISTS t1( t1_uid INT, t1_period DATETIME )", nil, nil )
        try db.execute("create table IF NOT EXISTS t2( t2_uid INT, t2_t1_uid INT, t2_period DATETIME )", nil, nil )
        try db.execute("insert into t1 (t1_uid, t1_period) values ( ? , ? )", [1, Date()], nil )
        try db.execute("insert into t2 (t2_uid, t2_t1_uid, t2_period) values ( ? , ? , ? )", [1, 1, Date()], nil )
        print( try db.query("select * from t1", nil, nil) )
        print( try db.query("select * from t2", nil, nil) )
        print( try db.query("select t1_uid+5 as first, t2_uid+10 as second, t1_period as period from t1,t2 where t2_t1_uid = t1_uid", nil, nil) )
        
        try db.close()
    }
    catch( let error ) {
        print(error)
    }
}
```

###Use your custom classes
```
class Person: NSObject {
    @objc var first: Int = 0   //Don't forget to add @objc to members!!
    @objc var second: Int = 0
    @objc var period: DateTime?
}
```

###Do your thing
```
do {
    try db.execute("create table IF NOT EXISTS t1( t1_uid INT, t1_period DATETIME )", nil, nil )
    try db.execute("create table IF NOT EXISTS t2( t2_uid INT, t2_t1_uid INT, t2_period DATETIME )", nil, nil )
    try db.execute("insert into t1 (t1_uid, t1_period) values ( ? , ? )", [1, Date()], nil )
    try db.execute("insert into t1 (t1_uid, t1_period) values ( ? , ? )", [2, Date()], nil )
    try db.execute("insert into t1 (t1_uid, t1_period) values ( ? , ? )", [3, Date()], nil )
    try db.execute("insert into t2 (t2_uid, t2_t1_uid, t2_period) values ( ? , ? , ? )", [1, 1, Date()], nil )
    
    let _ = try db.query("select t1_uid+5 as first, t2_uid+10 as second, t1_period as period from t1,t2 where t2_t1_uid = t1_uid", nil ) { ( row: Person) in
        print( row.first, row.second, row.period! )
        
    }
    
    OR
    
    let people: [Person] = try db.query("select t1_uid+5 as first, t2_uid+10 as second, t1_period as period from t1,t2 where t2_t1_uid = t1_uid", nil , nil )
    for row in people {
        print( row.first, row.second, row.period! )
    }
    
    
    try db.close()
    try db.remove()
}
catch( let error ) {
    print(error)
}

```

License
=======
Copyright 2022 Emmanuel Adigun. emmanuel@zignal.get

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
