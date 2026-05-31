module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2022,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "quotes": ["error", "double"],
    "object-curly-spacing": ["error", "never"],
    "require-jsdoc": "off",
    "max-len": ["error", {"code": 100}],
  },
};
