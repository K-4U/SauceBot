# SauceBot Command Variable Handler

# Commands:
#
# botname - Name of the bot
#    - botname -> SauceBot
# botversion - Version of the current bot
#   - botversion -> 2.7
#
# name - Name of the command-source
#   - name -> ravn_tm
# channel - Channel name
#   - channel -> CilantroGamer
#
# rand(val1, [val2, [val3, [...]]]) - Random number generator
#  - rand(5) -> 4
#  - rand(10, 15) -> 12
#  - rand(a, b, c, d, e) -> d
#
# time(timezone) - Current time
#   - timezone('GMT') -> 13:15:22
# countdown(timezone, ...) - Counts down to something
#
#
# Examples:
#
# !greetme : Hello, there, $(name)! Welcome to $(channel)!
# !now     : The current time for $(channel) is $(time US/Eastern)
# !dir     : You should go... $(rand Left, Right, Up, Down)!
# !bot     : [Bot] Running $(botname) version $(botversion)
#


tz         = require '../common/time'
color      = require 'colors'
os         = require 'os'

Sauce      = require './sauce'

varRE  = /\$\(([-!a-zA-Z_0-9]+)(?:\s+([^)]+))?\)/
varREB = /\$\[([-!a-zA-Z_0-9]+)(?:\s+([^)]+))?\]/

varREg = /\$\(([-!a-zA-Z_0-9]+)(?:\s+([^)]+))?\)/g

botStart = Date.now()

getUptime = (fmt) ->
    uptime = Date.now() - botStart
    tz.formatTime uptime, fmt

# MineCraft chat colours
colors =
        BLACK       : '§0'
        DARK_BLUE   : '§1'
        DARK_GREEN  : '§2'
        DARK_AQUA   : '§3'
        DARK_RED    : '§4'
        DARK_PURPLE : '§5'
        GOLD        : '§6'
        GRAY        : '§7'
        DARK_GRAY   : '§8'
        BLUE        : '§9'
        GREEN       : '§a'
        AQUA        : '§b'
        RED         : '§c'
        LIGHT_PURPLE: '§d'
        YELLOW      : '§e'
        WHITE       : '§f'
        MAGIC       : '§k'
        
class Vars
    constructor: (@channel) ->
        @handlers = {}


        baseVars = {
            botname   : (user, args, cb) -> cb Sauce.Server.Name
            botversion: (user, args, cb) -> cb Sauce.Version
            uptime    : (user, args, cb) -> cb getUptime(args[0])
            
            name      : (user, args, cb) -> cb user.name
            channel   : (user, args, cb) => cb @channel.name
            
            col       : (user, args, cb) -> cb (if args? and args[0]? then colors[args[0].toUpperCase()] else colors['WHITE'])
        
            rand      : (user, args, cb) ->
                return cb() unless args
                
                switch args.length
                        when 1
                            a = parseInt(args[0], 10)
                            return cb ~~ (Math.random() * a)
                        when 2
                            a = parseInt(args[0], 10)
                            b = parseInt(args[1], 10)
                            return cb ~~ (Math.random() * (b - a)) + a
                        else
                            idx = ~~ (Math.random() * args.length)
                            return cb args[idx]
                        
            
            time      : (user, args, cb) ->
                cb tz.formatZone(args[0] ? 'Europe/Amsterdam')

        }

        # Register default vars and pretend they're from the "Base" module.
        for cmd, handler of baseVars
            @register { name: 'Base' }, cmd, handler
                    
                    
    register: (module, cmd, handler) ->
        @handlers[cmd] = {
            module: module.name
            handle: handler
        }
        
        
    unregister: (cmd) ->
        delete @handlers[cmd]


    unregisterFor: (module) ->
        for cmd, handler of @handlers when handler.module is module.name
            @unregister cmd
   
 
    parse: (user, message, raw, cb) ->
        if m = @checkSpecialVars message
            @replaceVar m, message, user, raw, (replaced) =>
                @parse user, replaced, raw, cb
        else
            if m = @checkVars message
                @replaceVar m, message, user, raw, (replaced) =>
                    @parse user, replaced, raw, cb
            else
                cb message
            
            
    checkVars: (message) ->
        return unless '$' in message
        varRE.exec message
       
    checkSpecialVars: (message) ->
        return unless '$' in message
        varREB.exec message
        
    replaceVar: (m, msg, user, raw, cb) ->
        cmd  = m[1]
        args = if m[2] then m[2].split ',' else []
        
        @handle user, cmd, args, raw, (result) ->
            idx = m.index
            len = m[0].length
            
            pre  = msg.substring 0, idx
            post = msg.substring idx + len
            
            cb pre + result + post
        

    handle: (user, cmd, args, raw, cb) ->
        
        # Check for positional variables
        if /^-?\d+?$/.test cmd
            cmd = parseInt cmd, 10
            
            if cmd < 0
                cmd = (-cmd) - 1
                # Negative index means from N to the end
                return cb (((raw.split ' ')[cmd...] ? []).join ' ')
            else
                # Positive index means only the Nth word
                return cb ((raw.split ' ')[cmd - 1] ? '')
            
        # Otherwise, either return the command,
        # or handle it with the configured handler.
        return cb() unless variable = @handlers[cmd]
        variable.handle user, args, cb
        
    strip: (msg) ->
        msg.replace varREg, ''



exports.Vars = Vars
