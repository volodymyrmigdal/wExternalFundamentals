( function _External_s_() {

'use strict';

/**
 * Collection of routines to execute system commands, run shell, batches, launch external processes from JavaScript application. ExecTools leverages not only outputting data from an application but also inputting, makes application arguments parsing and accounting easier. Use the module to get uniform experience from interaction with an external processes on different platforms and operating systems.
  @module Tools/base/ExternalFundamentals
*/

/**
 * @file ExternalFundamentals.s.
 */

if( typeof module !== 'undefined' )
{

  let _ = require( '../../Tools.s' );

  _.include( 'wPathFundamentals' );
  _.include( 'wGdfStrategy' );

}

let System, ChildProcess, Deasync;
let _global = _global_;
let _ = _global_.wTools;
let Self = _global_.wTools;

_.assert( !!_realGlobal_ );

// --
// exec
// --

function shell( o )
{

  if( _.strIs( o ) )
  o = { execPath : o };

  _.routineOptions( shell, o );
  _.assert( arguments.length === 1, 'Expects single argument' );
  _.assert( o.args === null || _.arrayIs( o.args ) );
  _.assert( _.arrayHas( [ 'fork', 'exec', 'spawn', 'shell' ], o.mode ) );
  _.assert( _.strIs( o.execPath ) || _.strsAreAll( o.execPath ), 'Expects string or strings {-o.execPath-}, but got', _.strType( o.execPath ) );
  _.assert( o.timeOut === null || _.numberIs( o.timeOut ), 'Expects null or number {-o.timeOut-}, but got', _.strType( o.timeOut ) );

  let state = 0;
  let currentExitCode;
  let killedByTimeout = false;
  let stderrOutput = '';
  let decoratedOutput = '';
  let decoratedErrorOutput = '';

  o.ready = o.ready || new _.Consequence().take( null );
  // if( o.execPath.length === 1 )
  // o.execPath = o.execPath[ 0 ];

  /* */

  if( _.arrayIs( o.execPath ) )
  return multiple();

  /*  */

  if( o.sync && !o.deasync )
  {
    let arg = o.ready.toResource();
    if( _.err( arg ) )
    throw err;
    single();
    end( undefined, o )
    return o;
  }
  else
  {
    o.ready.thenGive( single );
    o.ready.finallyKeep( end );
    if( o.sync && o.deasync )
    return waitForCon( o.ready );
    return o.ready;
  }

  /*  */

  function multiple()
  {

    if( o.execPath.length > 1 && o.outputAdditive === null )
    o.outputAdditive = 0;

    let prevReady = o.ready;
    let readies = [];
    let options = [];

    for( let p = 0 ; p < o.execPath.length ; p++ )
    {

      let currentReady = new _.Consequence();
      readies.push( currentReady );

      if( o.concurrent )
      {
        prevReady.then( currentReady );
      }
      else
      {
        prevReady.finally( currentReady );
        prevReady = currentReady;
      }

      let o2 = _.mapExtend( null, o );
      o2.execPath = o.execPath[ p ];
      o2.ready = currentReady;
      options.push( o2 );
      _.shell( o2 );

    }

    o.ready
    .andKeep( readies )
    .finally( ( err, arg ) =>
    {

      o.exitCode = 0;
      for( let a = 0 ; a < options.length-1 ; a++ )
      {
        let o2 = options[ a ];
        if( !o.exitCode && o2.exitCode )
        o.exitCode = o2.exitCode;
      }

      if( err )
      throw err;

      return arg;
    });

    if( o.sync && !o.deasync )
    return o;
    if( o.sync && o.deasync )
    return waitForCon( o.ready );

    return o.ready;
  }

  /*  */

  function single()
  {

    _.assert( state === 0 );
    state = 1;

    prepare();
    launch();
    pipe();

  }

  /* */

  function end( err, arg )
  {

    if( state > 0 )
    {
      if( !o.outputAdditive )
      {
        if( decoratedOutput )
        o.logger.log( decoratedOutput );
        if( decoratedErrorOutput )
        o.logger.error( decoratedErrorOutput );
      }
    }

    if( err )
    throw err;
    return arg;
  }

  /* */

  function prepare()
  {

    if( o.outputAdditive === null )
    o.outputAdditive = true;
    o.outputAdditive = !!o.outputAdditive;
    o.currentPath = o.currentPath || _.path.current();
    o.logger = o.logger || _global_.logger;

    /* verbosity */

    if( !_.numberIs( o.verbosity ) )
    o.verbosity = o.verbosity ? 1 : 0;
    if( o.verbosity < 0 )
    o.verbosity = 0;
    if( o.outputPiping === null )
    o.outputPiping = o.verbosity >= 2;
    if( o.outputCollecting && !o.output )
    o.output = '';

    /* ipc */

    if( o.ipc )
    {
      if( _.strIs( o.stdio ) )
      o.stdio = _.dup( o.stdio, 3 );
      if( !_.arrayHas( o.stdio, 'ipc' ) )
      o.stdio.push( 'ipc' );
    }

    /* passingThrough */

    if( o.passingThrough )
    {
      let argumentsManual = process.argv.slice( 2 );
      if( argumentsManual.length )
      o.args = _.arrayAppendArray( o.args || [], argumentsManual );
    }

    /* out options */

    o.fullPath = _.strConcat( _.arrayAppendArray( [ o.execPath ], o.args || [] ) );
    o.exitCode = null;
    o.exitSignal = null;
    o.process = null;
    Object.preventExtensions( o );

    /* dependencies */

    if( !ChildProcess )
    ChildProcess = require( 'child_process' );

    if( !o.outputGray && typeof module !== 'undefined' )
    try
    {
      _.include( 'wLogger' );
      _.include( 'wColor' );
    }
    catch( err )
    {
      if( o.verbosity )
      _.errLogOnce( err );
    }

  }

  /* */

  function launch()
  {

    /* logger */

    try
    {

      if( o.verbosity && o.inputMirroring )
      {
        let prefix = ' > ';
        if( !o.outputGray )
        prefix = _.color.strFormat( prefix, { fg : 'bright white' } );
        log( prefix + o.fullPath );
      }

    }
    catch( err )
    {
      debugger;
      _.errLogOnce( err );
    }

    /* launch */

    try
    {

      launchAct();

    }
    catch( err )
    {
      debugger
      appExitCode( -1 );
      if( o.sync && !o.deasync )
      throw _.errLogOnce( err );
      else
      return o.ready.error( _.errLogOnce( err ) );
    }

    /* time out */

    if( o.timeOut )
    if( !o.sync || o.deasync )
    _.timeBegin( o.timeOut, () =>
    {
      if( state === 2 )
      return;
      killedByTimeout = true;
      o.process.kill( 'SIGTERM' );
    });

  }

  /* */

  function launchAct()
  {

    if( _.strIs( o.interpreterArgs ) )
    o.interpreterArgs = _.strSplitNonPreserving({ src : o.interpreterArgs });

    if( o.mode === 'fork')
    {
      _.assert( !o.sync || o.deasync, '{ shell.mode } "fork" is available only in async/deasync version of shell' );
      let args = o.args || [];
      let o2 = optionsForFork();
      o.process = ChildProcess.fork( o.execPath, args, o2 );
    }
    else if( o.mode === 'exec' )
    {
      let currentPath = _.path.nativize( o.currentPath );
      log( '{ shell.mode } "exec" is deprecated' );
      if( o.sync && !o.deasync )
      o.process = ChildProcess.execSync( o.execPath, { env : o.env, cwd : currentPath } );
      else
      o.process = ChildProcess.exec( o.execPath, { env : o.env, cwd : currentPath } );
    }
    else if( o.mode === 'spawn' )
    {
      let appPath = o.execPath;

      if( !o.args )
      {
        o.args = _.strSplitNonPreserving({ src : o.execPath });
        appPath = o.args.shift();
      }
      else
      {
        if( appPath.length )
        _.assert( _.strSplitNonPreserving({ src : appPath }).length === 1, ' o.execPath must not contain arguments if those were provided through options' )
      }

      let o2 = optionsForSpawn();

      if( o.sync && !o.deasync )
      o.process = ChildProcess.spawnSync( appPath, o.args, o2 );
      else
      o.process = ChildProcess.spawn( appPath, o.args, o2 );

    }
    else if( o.mode === 'shell' )
    {

      let appPath = process.platform === 'win32' ? 'cmd' : 'sh';
      let arg1 = process.platform === 'win32' ? '/c' : '-c';
      let arg2 = o.execPath;
      let o2 = optionsForSpawn();

      o2.windowsVerbatimArguments = true; /* qqq : explain why is it needed please */

      if( o.args && o.args.length )
      arg2 = arg2 + ' ' + '"' + o.args.join( '" "' ) + '"';

      if( o.sync && !o.deasync )
      o.process = ChildProcess.spawnSync( appPath, [ arg1, arg2 ], o2 );
      else
      o.process = ChildProcess.spawn( appPath, [ arg1, arg2 ], o2 );

    }
    else _.assert( 0, 'Unknown mode', _.strQuote( o.mode ), 'to shell path', _.strQuote( o.paths ) );

  }

  /* */

  function optionsForSpawn()
  {
    let o2 = Object.create( null );
    if( o.stdio )
    o2.stdio = o.stdio;
    o2.detached = !!o.detaching;
    if( o.env )
    o2.env = o.env;
    if( o.currentPath )
    o2.cwd = _.path.nativize( o.currentPath );
    if( o.timeOut && o.sync )
    o2.timeout = o.timeOut;
    return o2;
  }

  /* */

  function optionsForFork()
  {
    let interpreterArgs = o.interpreterArgs || process.execArgv;
    let o2 =
    {
      silent : false,
      env : o.env,
      cwd : _.path.nativize( o.currentPath ),
      stdio : o.stdio,
      execArgv : interpreterArgs,
    }
    return o2;
  }

  /* */

  function pipe()
  {

    /* piping out channel */

    if( o.outputPiping || o.outputCollecting )
    if( o.process.stdout )
    if( o.sync && !o.deasync )
    handleStdout( o.process.stdout );
    else
    o.process.stdout.on( 'data', handleStdout );

    /* piping error channel */

    if( o.process.stderr )
    if( o.sync && !o.deasync )
    handleStderr( o.process.stderr );
    else
    o.process.stderr.on( 'data', handleStderr );

    if( o.sync && !o.deasync )
    {
      if( o.process.error )
      handleError( o.process.error );
      else
      handleClose( o.process.status, o.process.signal );
    }
    else
    {
      o.process.on( 'error', handleError );
      o.process.on( 'close', handleClose );
    }

  }

  /* */

  function appExitCode( exitCode )
  {
    if( currentExitCode )
    return;
    if( o.applyingExitCode && exitCode !== 0 )
    {
      currentExitCode = _.numberIs( exitCode ) ? exitCode : -1;
      _.appExitCode( currentExitCode );
    }
  }

  /* */

  function infoGet()
  {
    let result = '';
    result += 'Launched as ' + _.strQuote( o.fullPath ) + '\n';
    result += 'Launched at ' + _.strQuote( o.currentPath ) + '\n';
    if( stderrOutput.length )
    result += '\n -> Stderr' + '\n' + _.strIndentation( stderrOutput, ' -  ' ) + '\n -< Stderr'; // !!! : implement error's collectors
    return result;
  }

  /* */

  function handleClose( exitCode, exitSignal )
  {

    o.exitCode = exitCode;
    o.exitSignal = exitSignal;

    if( o.verbosity >= 5 )
    {
      log( 'Process returned error code ' + exitCode );
      if( exitCode )
      {
        log( infoGet() );
      }
    }

    if( state === 2 )
    return;

    state = 2;

    appExitCode( exitCode );

    if( exitCode !== 0 && o.throwingExitCode )
    {
      let err;

      if( _.numberIs( exitCode ) )
      err = _.err( 'Process returned exit code', exitCode, '\n', infoGet() );
      else if( killedByTimeout )
      err = _.err( 'Process timed out, killed by exit signal', exitSignal, '\n', infoGet() );
      else
      err = _.err( 'Process wass killed by exit signal', exitSignal, '\n', infoGet() );

      if( o.sync && !o.deasync )
      throw err;
      else
      o.ready.error( err );
    }
    else if( !o.sync || o.deasync )
    {
      o.ready.take( o );
    }

  }

  /* */

  function handleError( err )
  {

    appExitCode( -1 );

    if( state === 2 )
    return;

    state = 2;

    debugger;
    err = _.err( 'Error shelling command\n', o.execPath, '\nat', o.currentPath, '\n', err );
    if( o.verbosity )
    err = _.errLogOnce( err );

    if( o.sync && !o.deasync )
    throw err;
    else
    o.ready.error( err );
  }

  /* */

  function handleStderr( data )
  {

    if( _.bufferAnyIs( data ) )
    data = _.bufferToStr( data );

    stderrOutput += data;

    if( o.outputCollecting )
    o.output += data;

    if( !o.outputPiping )
    return;

    if( _.strEnds( data, '\n' ) )
    data = _.strRemoveEnd( data, '\n' );

    if( o.outputPrefixing )
    data = 'stderr :\n' + _.strIndentation( data, '  ' );

    if( _.color && !o.outputGray )
    data = _.color.strFormat( data, 'pipe.negative' );

    log( data, 1 );
  }

  /* */

  function handleStdout( data )
  {

    if( _.bufferAnyIs( data ) )
    data = _.bufferToStr( data );

    if( o.outputCollecting )
    o.output += data;
    if( !o.outputPiping )
    return;

    if( _.strEnds( data, '\n' ) )
    data = _.strRemoveEnd( data, '\n' );

    if( o.outputPrefixing )
    data = 'stdout :\n' + _.strIndentation( data, '  ' );

    if( _.color && !o.outputGray && !o.outputGrayStdout )
    data = _.color.strFormat( data, 'pipe.neutral' );

    log( data );

  }

  /* */

  function log( msg, isError )
  {

    if( o.outputAdditive )
    {
      if( isError )
      o.logger.error( msg );
      else
      o.logger.log( msg );
    }
    else
    {
      decoratedOutput += msg + '\n';
      if( isError )
      decoratedErrorOutput += msg + '\n';
    }

  }

  /* */

  /* qqq : use Consequence.deasync */
  function waitForCon( con )
  {
    let ready = false;
    let result = Object.create( null );

    con.got( ( err, data ) =>
    {
      result.err = err;
      result.data = data;
      ready = true;
    })

    if( !Deasync )
    Deasync = require( 'deasync' );
    Deasync.loopWhile( () => !ready )

    if( result.err )
    throw result.err;
    return result.data;
  }

}

/*
qqq : implement currentPath for all modes
*/

shell.defaults =
{

  execPath : null,
  currentPath : null,

  sync : 0,
  deasync : 1,

  args : null,
  interpreterArgs : null,
  mode : 'shell', /* 'fork', 'exec', 'spawn', 'shell' */
  ready : null,
  logger : null,

  env : null,
  stdio : 'pipe', /* 'pipe' / 'ignore' / 'inherit' */
  ipc : 0,
  detaching : 0,
  passingThrough : 0,
  concurrent : 0,
  timeOut : null,

  throwingExitCode : 1, /* must be on by default */
  applyingExitCode : 0,

  verbosity : 2,
  outputGray : 0,
  outputGrayStdout : 0,
  outputPrefixing : 0,
  outputPiping : null,
  outputCollecting : 0,
  outputAdditive : null,
  inputMirroring : 1,

}

//

function sheller( o0 )
{
  _.assert( arguments.length === 0 || arguments.length === 1 );
  if( _.strIs( o0 ) )
  o0 = { execPath : o0 }
  o0 = _.routineOptions( sheller, o0 );
  o0.ready = o0.ready || new _.Consequence().take( null );

  return function er()
  {
    let o = optionsFrom( arguments[ 0 ] );
    let o00 = _.mapExtend( null, o0 );
    merge( o00, o );
    _.mapExtend( o, o00 )

    for( let a = 1 ; a < arguments.length ; a++ )
    {
      let o1 = optionsFrom( arguments[ a ] );
      merge( o, o1 );
      _.mapExtend( o, o1 );
    }

    return _.shell( o );
  }

  function optionsFrom( options )
  {
    if( _.strIs( options ) || _.arrayIs( options ) )
    options = { execPath : options }
    options = options || Object.create( null );
    _.assertMapHasOnly( options, sheller.defaults );
    return options;
  }

  function merge( dst, src )
  {
    if( _.strIs( src ) || _.arrayIs( src ) )
    src = { execPath : src }
    _.assertMapHasOnly( src, sheller.defaults );

    if( src.execPath && dst.execPath )
    {
      _.assert( _.arrayIs( src.execPath ) || _.strIs( src.execPath ), () => 'Expects string or array, but got ' + _.strType( src.execPath ) );
      if( _.arrayIs( src.execPath ) )
      src.execPath = _.arrayFlatten( src.execPath );
      dst.execPath = _.eachSample( [ dst.execPath, src.execPath ] ).map( ( path ) => path.join( ' ' ) );
      delete src.execPath;
    }

    _.mapExtend( dst, src );

    return dst;
  }

}

sheller.defaults = Object.create( shell.defaults );

//

function shellNode( o )
{

  if( !System )
  System = require( 'os' );

  _.include( 'wPathFundamentals' );
  _.include( 'wFiles' );

  if( _.strIs( o ) )
  o = { execPath : o }

  _.routineOptions( shellNode, o );
  _.assert( _.strIs( o.execPath ) );
  _.assert( !o.code );
  _.accessor.forbid( o, 'child' );
  _.accessor.forbid( o, 'returnCode' );
  _.assert( arguments.length === 1, 'Expects single argument' );

  /*
  1024*1024 for megabytes
  1.4 factor found empirically for windows
      implementation of nodejs for other OSs could be able to use more memory
  */

  let interpreterArgs = '';
  if( o.maximumMemory )
  {
    let totalmem = System.totalmem();
    if( o.verbosity )
    logger.log( 'System.totalmem()', _.strMetricFormatBytes( totalmem ) );
    if( totalmem < 1024*1024*1024 )
    Math.floor( ( totalmem / ( 1024*1024*1.4 ) - 1 ) / 256 ) * 256;
    else
    Math.floor( ( totalmem / ( 1024*1024*1.1 ) - 1 ) / 256 ) * 256;
    interpreterArgs = '--expose-gc --stack-trace-limit=999 --max_old_space_size=' + totalmem;
  }

  let path = _.fileProvider.path.nativize( o.execPath );
  if( o.mode === 'fork' )
  o.interpreterArgs = interpreterArgs;
  else
  path = _.strConcat([ 'node', interpreterArgs, path ]);

  let shellOptions = _.mapOnly( o, _.shell.defaults );
  shellOptions.execPath = path;

  let result = _.shell( shellOptions )
  .got( function( err, arg )
  {
    o.exitCode = shellOptions.exitCode;
    o.exitSignal = shellOptions.exitSignal;
    this.take( err, arg );
  });

  o.ready = shellOptions.ready;
  o.process = shellOptions.process;

  return result;
}

var defaults = shellNode.defaults = Object.create( shell.defaults );

defaults.passingThrough = 0;
defaults.maximumMemory = 0;
defaults.applyingExitCode = 1;
defaults.stdio = 'inherit';

//

function shellNodePassingThrough( o )
{

  if( _.strIs( o ) )
  o = { execPath : o }

  _.routineOptions( shellNodePassingThrough, o );
  _.assert( arguments.length === 1, 'Expects single argument' );
  let result = _.shellNode( o );

  return result;
}

var defaults = shellNodePassingThrough.defaults = Object.create( shellNode.defaults );

defaults.passingThrough = 1;
defaults.maximumMemory = 1;
defaults.applyingExitCode = 1;

// --
// app
// --

let _appArgsCache;
let _appArgsInSamFormat = Object.create( null )
var defaults = _appArgsInSamFormat.defaults = Object.create( null );

defaults.keyValDelimeter = ':';
defaults.subjectsDelimeter = ';';
defaults.argv = null;
defaults.caching = true;
defaults.parsingArrays = true;

//

function _appArgsInSamFormatNodejs( o )
{

  _.assert( arguments.length === 0 || arguments.length === 1 );
  o = _.routineOptions( _appArgsInSamFormatNodejs, arguments );

  if( o.caching )
  if( _appArgsCache && o.keyValDelimeter === _appArgsCache.keyValDelimeter && o.subjectsDelimeter === _appArgsCache.subjectsDelimeter )
  return _appArgsCache;

  let result = Object.create( null );

  if( o.caching )
  if( o.keyValDelimeter === _appArgsInSamFormatNodejs.defaults.keyValDelimeter )
  _appArgsCache = result;

  if( !_global.process )
  {
    result.subject = '';
    result.map = Object.create( null );
    result.subjects = [];
    result.maps = [];
    return result;
  }

  o.argv = o.argv || process.argv;

  _.assert( _.longIs( o.argv ) );

  result.interpreterPath = _.path.normalize( o.argv[ 0 ] );
  result.mainPath = _.path.normalize( o.argv[ 1 ] );
  result.interpreterArgs = process.execArgv;
  result.scriptArgs = o.argv.slice( 2 );
  result.scriptString = result.scriptArgs.join( ' ' );
  result.scriptString = result.scriptString.trim();

  let r = _.strRequestParse
  ({
    src : result.scriptString,
    keyValDelimeter : o.keyValDelimeter,
    subjectsDelimeter : o.subjectsDelimeter,
    parsingArrays : o.parsingArrays,
  });

  _.mapExtend( result, r );

  return result;
}

_appArgsInSamFormatNodejs.defaults = Object.create( _appArgsInSamFormat.defaults );

//

function _appArgsInSamFormatBrowser( o )
{
  debugger; /* xxx */

  _.assert( arguments.length === 0 || arguments.length === 1 );
  o = _.routineOptions( _appArgsInSamFormatNodejs, arguments );

  if( o.caching )
  if( _appArgsCache && o.keyValDelimeter === _appArgsCache.keyValDelimeter )
  return _appArgsCache;

  let result = Object.create( null );

  result.map =  Object.create( null );

  if( o.caching )
  if( o.keyValDelimeter === _appArgsInSamFormatNodejs.defaults.keyValDelimeter )
  _appArgsCache = result;

  return result;
}

_appArgsInSamFormatBrowser.defaults = Object.create( _appArgsInSamFormat.defaults );

//

function appArgsReadTo( o )
{

  if( arguments[ 1 ] !== undefined )
  o = { dst : arguments[ 0 ], namesMap : arguments[ 1 ] };

  o = _.routineOptions( appArgsReadTo, o );

  if( !o.propertiesMap )
  o.propertiesMap = _.appArgs().map;

  if( _.arrayIs( o.namesMap ) )
  {
    let namesMap = Object.create( null );
    for( let n = 0 ; n < o.namesMap.length ; n++ )
    namesMap[ o.namesMap[ n ] ] = o.namesMap[ n ];
    o.namesMap = namesMap;
  }

  _.assert( arguments.length === 1 || arguments.length === 2 )
  _.assert( _.objectIs( o.dst ), 'Expects map {-o.dst-}' );
  _.assert( _.objectIs( o.namesMap ), 'Expects map {-o.namesMap-}' );

  for( let n in o.namesMap )
  {
    if( o.propertiesMap[ n ] !== undefined )
    {
      set( o.namesMap[ n ], o.propertiesMap[ n ] );
      if( o.removing )
      delete o.propertiesMap[ n ];
    }
  }

  if( o.only )
  {
    let but = Object.keys( _.mapBut( o.propertiesMap, o.namesMap ) );
    if( but.length )
    {
      throw _.err( 'Unknown application arguments : ' + _.strQuote( but ).join( ', ' ) );
    }
  }

  return o.propertiesMap;

  /* */

  function set( k, v )
  {
    _.assert( o.dst[ k ] !== undefined, () => 'Entry ' + _.strQuote( k ) + ' is not defined' );
    if( _.numberIs( o.dst[ k ] ) )
    {
      v = Number( v );
      _.assert( !isNaN( v ) );
      o.dst[ k ] = v;
    }
    else if( _.boolIs( o.dst[ k ] ) )
    {
      v = !!v;
      o.dst[ k ] = v;
    }
    else
    {
      o.dst[ k ] = v;
    }
  }

}

appArgsReadTo.defaults =
{
  dst : null,
  propertiesMap : null,
  namesMap : null,
  removing : 1,
  only : 1,
}

//

function appAnchor( o )
{
  o = o || {};

  _.routineOptions( appAnchor, arguments );

  let a = _.strToMap
  ({
    src : _.strRemoveBegin( window.location.hash, '#' ),
    keyValDelimeter : ':',
    entryDelimeter : ';',
  });

  if( o.extend )
  {
    _.mapExtend( a, o.extend );
  }

  if( o.del )
  {
    _.mapDelete( a, o.del );
  }

  if( o.extend || o.del )
  {

    let newHash = '#' + _.mapToStr
    ({
      src : a,
      keyValDelimeter : ':',
      entryDelimeter : ';',
    });

    if( o.replacing )
    history.replaceState( undefined, undefined, newHash )
    else
    window.location.hash = newHash;

  }

  return a;
}

appAnchor.defaults =
{
  extend : null,
  del : null,
  replacing : 0,
}

//

function appExitCode( status )
{
  let result;

  _.assert( arguments.length === 0 || arguments.length === 1 );
  _.assert( status === undefined || _.numberIs( status ) );

  if( _global.process )
  {
    if( status !== undefined )
    process.exitCode = status;
    result = process.exitCode;
  }

  return result;
}

//

function appExit( exitCode )
{

  exitCode = exitCode !== undefined ? exitCode : appExitCode();

  _.assert( arguments.length === 0 || arguments.length === 1 );
  _.assert( exitCode === undefined || _.numberIs( exitCode ) );

  if( _global.process )
  {
    process.exit( exitCode );
  }
  else
  {
    /*debugger;*/
  }

}

//

function appExitWithBeep( exitCode )
{

  exitCode = exitCode !== undefined ? exitCode : appExitCode();

  _.assert( arguments.length === 0 || arguments.length === 1 );
  _.assert( exitCode === undefined || _.numberIs( exitCode ) );

  _.diagnosticBeep();

  if( exitCode )
  _.diagnosticBeep();

  _.appExit( exitCode );
}

//

let appRepairExitHandlerDone = 0;
function appRepairExitHandler()
{

  _.assert( arguments.length === 0 );

  if( appRepairExitHandlerDone )
  return;
  appRepairExitHandlerDone = 1;

  if( typeof process === 'undefined' )
  return;

  process.on( 'SIGINT', function()
  {
    console.log( 'SIGINT' );
    try
    {
      process.exit();
    }
    catch( err )
    {
      console.log( 'Error!' );
      console.log( err.toString() );
      console.log( err.stack );
      process.removeAllListeners( 'exit' );
      process.exit();
    }
  });

  process.on( 'SIGUSR1', function()
  {
    console.log( 'SIGUSR1' );
    try
    {
      process.exit();
    }
    catch( err )
    {
      console.log( 'Error!' );
      console.log( err.toString() );
      console.log( err.stack );
      process.removeListener( 'exit' );
      process.exit();
    }
  });

  process.on( 'SIGUSR2', function()
  {
    console.log( 'SIGUSR2' );
    try
    {
      process.exit();
    }
    catch( err )
    {
      console.log( 'Error!' );
      console.log( err.toString() );
      console.log( err.stack );
      process.removeListener( 'exit' );
      process.exit();
    }
  });

}

//

function appRegisterExitHandler( routine )
{
  _.assert( arguments.length === 1 );
  _.assert( _.routineIs( routine ) );

  if( typeof process === 'undefined' )
  return;

  process.once( 'exit', onExitHandler );
  process.once( 'SIGINT', onExitHandler );
  process.once( 'SIGTERM', onExitHandler );

  /*  */

  function onExitHandler( arg )
  {
    try
    {
      routine( arg );
    }
    catch( err )
    {
      _.errLogOnce( err );
    }
    process.removeListener( 'exit', onExitHandler );
    process.removeListener( 'SIGINT', onExitHandler );
    process.removeListener( 'SIGTERM', onExitHandler );
  }

}

//

function appMemoryUsageInfo()
{
  var usage = process.memoryUsage();
  return ( usage.heapUsed >> 20 ) + ' / ' + ( usage.heapTotal >> 20 ) + ' / ' + ( usage.rss >> 20 ) + ' Mb';
}

// --
// declare
// --

let Proto =
{

  shell,
  sheller,
  shellNode,
  shellNodePassingThrough,

  //

  _appArgsInSamFormatNodejs,
  _appArgsInSamFormatBrowser,

  appArgsInSamFormat : Config.platform === 'nodejs' ? _appArgsInSamFormatNodejs : _appArgsInSamFormatBrowser,
  appArgs : Config.platform === 'nodejs' ? _appArgsInSamFormatNodejs : _appArgsInSamFormatBrowser,
  appArgsReadTo,

  appAnchor,

  appExitCode,
  appExit,
  appExitWithBeep,

  appRepairExitHandler,
  appRegisterExitHandler,

  appMemoryUsageInfo,

}

_.mapExtend( Self, Proto );

// --
// export
// --

// if( typeof module !== 'undefined' )
// if( _global_.WTOOLS_PRIVATE )
// { /* delete require.cache[ module.id ]; */ }

if( typeof module !== 'undefined' && module !== null )
module[ 'exports' ] = Self;

})();