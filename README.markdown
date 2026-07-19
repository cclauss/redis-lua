# redis-lua #

## About ##

redis-lua is a pure Lua client library for the Redis advanced key-value database.

This repository is the 3.0 continuation of the original <https://github.com/nrk/redis-lua>.

## Installation ##

The library is published on LuaRocks under the name `redis-lua3`:

``` shell
luarocks install redis-lua3
```

## Main features ##

- Support for Redis >= 1.2
- Command pipelining
- Redis transactions (MULTI/EXEC) with CAS
- User-definable commands
- UNIX domain sockets (when available in LuaSocket)
- TLS connections (when LuaSec is installed)

## Compatibility ##

This library is tested and works with __Lua 5.1__ thru __5.4__ (using a compatible
version of LuaSocket) and __LuaJit 2.1__.

## Examples of usage ##

### Include redis-lua in your script ###

Just require the `redis` module, assigning it to a variable:

``` lua
local redis = require 'redis'
```

### Connect to a Redis server instance and send a PING command ###

``` lua
local redis = require 'redis'
local client = redis.connect('127.0.0.1', 6379)
local response = client:ping()           -- true
```

Credentials and a database number can be supplied in a `redis://` URI or in the
table of connection parameters. The client will automatically send AUTH (with
ACL username support on Redis >= 6) and SELECT when connecting:

``` lua
local client = redis.connect('redis://myuser:secret@127.0.0.1:6379/2')

-- equivalent:
local client = redis.connect({
    host     = '127.0.0.1',
    port     = 6379,
    username = 'myuser',   -- omit to authenticate with the password only
    password = 'secret',
    database = 2,
})
```

The `timeout` parameter sets the socket timeout in seconds for every operation,
including connecting. Use `connect_timeout` to limit only the connection step.
The timeout can be changed later with `client:set_timeout(seconds)`, for
example, to disable it before a blocking command:

``` lua
local client = redis.connect({ host = '127.0.0.1', connect_timeout = 5 })
client:set_timeout(nil)
client:blpop('queue', 0)
```

Connections can be encrypted with __TLS__ when the optional
[LuaSec](https://github.com/lunarmodules/luasec) module is installed. Use the
`rediss://` scheme or set the `tls` parameter, which accepts `true` or a table
of LuaSec options. The server certificate is verified against the system CA
store by default, or against `cafile` when given:

``` lua
local client = redis.connect('rediss://127.0.0.1:6390')

local client = redis.connect({
    host = '127.0.0.1',
    port = 6390,
    tls  = { cafile = '/path/to/ca.crt' },
})

local client = redis.connect({
    host = '127.0.0.1',
    port = 6390,
    tls  = { verify = 'none' },    -- disable certificate verification
})
```

Note that LuaSec verifies the certificate chain but does not check that the
certificate matches the hostname you connected to.

It is also possible to connect to a local redis instance using __UNIX domain sockets__
if LuaSocket has been compiled with them enabled (unfortunately, this is not the default):

``` lua
local redis = require 'redis'
local client = redis.connect('unix:///tmp/redis.sock')
```

### Set keys and get their values ###

``` lua
client:set('usr:nrk', 10)
client:set('usr:nobody', 5)
local value = client:get('usr:nrk')      -- 10
```

### Sort list values by using various parameters supported by the server ###

``` lua
for _,v in ipairs({ 10,3,2,6,1,4,23 }) do
    client:rpush('usr:nrk:ids',v)
end

local sorted = client:sort('usr:nrk:ids', {
     sort = 'asc', alpha = true, limit = { 1, 5 }
})      -- {1=10,2=2,3=23,4=3,5=4}
```

### Pipeline commands

``` lua
local replies = client:pipeline(function(p)
    p:incrby('counter', 10)
    p:incrby('counter', 30)
    p:get('counter')
end)
```

When a command in the pipeline fails, the replies of the remaining commands
are still read. The reply for a failed command is a table of the form
`{ error = message }`. Only connection errors raise a Lua error.

### Variadic commands

Some commands such as RPUSH, SADD, SINTER and others have been improved in Redis 2.4
to accept a list of values or keys depending on the nature of the command. Sometimes
it can be useful to pass these arguments as a list in a table, but since redis-lua does
not currently do anything to handle such a case you can use `unpack()` albeit with a
limitation on the maximum number of items which is defined in Lua by LUAI_MAXCSTACK
(the default on Lua 5.1 is set to `8000`, see `luaconf.h`):

```lua
local values = { 'value1', 'value2', 'value3' }
client:rpush('list', unpack(values))

-- the previous line has the same effect of the following one:
client:rpush('list', 'value1', 'value2', 'value3')
```

### Leverage Redis MULTI / EXEC transaction (Redis > 2.0)

``` lua
local replies = client:transaction(function(t)
    t:incrby('counter', 10)
    t:incrby('counter', 30)
    t:get('counter')
end)
```

Commands that fail inside a transaction are reported in the same way as in
pipelines. The reply for a failed command is a table of the form
`{ error = message }`.

### Leverage WATCH / MULTI / EXEC for check-and-set (CAS) operations (Redis > 2.2)

``` lua
local options = { watch = "key_to_watch", cas = true, retry = 2 }
local replies = client:transaction(options, function(t)
    local val = t:get("key_to_watch")
    t:multi()
    t:set("akey", val)
    t:set("anotherkey", val)
end)
```

### Add or replace Redis commands ###

Any method not explicitly defined is automatically sent to the server as a plain
command of the same name, so commands introduced by newer Redis versions can be
used without waiting for redis-lua to define them:

```lua
client:unlink('key1', 'key2')       -- works even though redis-lua does not define UNLINK
```

Note that this means `client.foo` is never `nil`, even for commands that don't
exist. Calling a bad command name will only fail once the server rejects it.
Use `rawget(client, 'foo')` to check whether a command has actually been
defined.

You can also define new Redis commands or redefine existing ones at module level
(commands will be available on all client instances) or client level (commands
will be available only on that client instance), for example to attach custom
argument serializers or reply parsers.

```lua
local redis = require 'redis'
redis.commands.set = redis.command('set')   -- module level

local client = redis.connect()
client.get = redis.command('get')           -- client level
```

## Dependencies ##

- [Lua 5.1 thru 5.4](http://www.lua.org/) or [LuaJIT 2.1](http://luajit.org/)
- [LuaSocket 2.0](https://lunarmodules.github.io/luasocket)
- [LuaSec](https://github.com/lunarmodules/luasec) (optional, required for TLS connections)
- [Busted](https://lunarmodules.github.io/busted) (required to run the test suite)

Run the test suite against a local Redis instance with:

```shell
busted
```

## Links ##

### Project ###
- [Source code](https://github.com/leafo/redis-lua)
- [Issue tracker](https://github.com/leafo/redis-lua/issues)
- [Original redis-lua](https://github.com/nrk/redis-lua) by Daniele Alessandri

### Related ###
- [Redis](http://redis.io/)
- [Git](http://git-scm.com/)

## Authors ##

[Daniele Alessandri](mailto:suppakilla@gmail.com)

### Contributors ###

[Leo Ponomarev](http://github.com/slact/)

## License ##

The code for redis-lua is distributed under the terms of the MIT/X11 license (see LICENSE).
