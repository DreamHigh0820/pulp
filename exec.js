var files = require("./files");
var child = require("child_process");
var q = require("q");

function exec(cmd, quiet, args, env, callback) {
  var output = q.defer();
  var c = child.spawn(cmd, args, {
    stdio: [process.stdin, quiet ? "pipe" : process.stdout, process.stderr],
    env: env
  }).on("exit", function(code) {
    if (code > 0) {
      if (quiet) {
        output.promise.then(function(buf) {
          process.stderr.write(buf.toString("utf-8"));
          callback(new Error("Subcommand terminated with error code " + code), code);
        });
      } else {
        callback(new Error("Subcommand terminated with error code " + code), code);
      }
    } else {
      if (quiet) {
        output.promise.then(function(r) {
          callback(null, r.toString("utf-8"));
        });
      } else {
        callback(null);
      }
    }
  }).on("error", function(err) {
    if (err.code === "ENOENT") {
      // On Windows: if executable wasn't found, try adding .cmd
      if (process.platform == "win32") {
        if (!cmd.match(/\.cmd$/i)) {
          exec(cmd + ".cmd", quiet, args, env, callback)
        } else {
          var bareCmd = cmd.substr(0, cmd.length - 4)
          callback(new Error("`" + bareCmd + "` executable not found. (nor `" + cmd + "`)"));
        }
      }
      else {
        callback(new Error("`" + cmd + "` executable not found."));
      }
    }
  });
  if (quiet) {
    c.stdout.pipe(require("concat-stream")(function(data) {
      output.resolve(data);
    }));
  }
}

module.exports.psc = function(deps, ffi, args, env, callback) {
  var allArgs = args.concat(deps).concat([].concat.apply([], ffi.map(function(path) {
    return ["--ffi", path];
  })));
  exec("psc", true, allArgs, env, callback);
};

module.exports.pscBundle = function(dir, args, env, callback) {
  files.resolve(dir, function(err, deps) {
    if (err) {
      callback(err);
    } else {
      var allArgs = args.concat(deps);

      exec("psc-bundle", true, allArgs, env, callback);
    }
  });
};

module.exports.exec = exec;
