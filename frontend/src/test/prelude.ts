const cerr = console.error;

beforeEach(() => {
  console.error = function (...args) {
    cerr.apply(args);
    throw new Error(`console.error cannot be called during a test. Was called with [${args.join(", ")}].`);
  };
});
