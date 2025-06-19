export default {
    preset: "ts-jest",
    testEnvironment: "node",
    roots: ["<rootDir>/test", "<rootDir>/operator"],
    testMatch: [
        "**/__tests__/**/*.+(ts|tsx|js)",
        "**/*.(test|spec).+(ts|tsx|js)",
    ],
    transform: {
        "^.+\\.(ts|tsx)$": "ts-jest",
    },
    collectCoverageFrom: [
        "operator/**/*.{ts,js}",
        "scripts/**/*.{ts,js}",
        "!**/*.d.ts",
        "!**/node_modules/**",
    ],
    coverageDirectory: "coverage",
    coverageReporters: ["text", "lcov", "html"],
    setupFilesAfterEnv: ["<rootDir>/test/setup.ts"],
    testTimeout: 30000,
    verbose: true,
    forceExit: true,
    detectOpenHandles: true,
};
