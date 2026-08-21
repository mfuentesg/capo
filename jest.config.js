// eslint-disable-next-line @typescript-eslint/no-require-imports
const nextJest = require("next/jest")

const createJestConfig = nextJest({
  // Provide the path to your Next.js app to load next.config.js and .env files in your test environment
  dir: "./"
})

// Add any custom config to be passed to Jest
const customJestConfig = {
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  testEnvironment: "jest-environment-jsdom",
  // jsdom's default export condition resolves to cheerio's ESM "browser"
  // build, which Jest's CJS transform can't parse. Clearing the condition
  // list makes module resolution fall back to the standard Node build.
  testEnvironmentOptions: { customExportConditions: [""] },
  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/$1",
    "^react-resizable-panels$": "<rootDir>/__mocks__/react-resizable-panels.js"
  },
  testMatch: ["**/__tests__/**/*.[jt]s?(x)", "**/?(*.)+(spec|test).[jt]s?(x)"],
  testPathIgnorePatterns: ["/node_modules/", "/.next/", ".*fixtures\\.ts$", "/.worktrees/"],
  collectCoverageFrom: [
    "app/auth/callback/route.ts",
    "features/**/api/actions.ts",
    "features/auth/api/authApi.ts",
    "features/songs/utils/cifraclub/*.ts",
    "features/**/hooks/query-keys.ts",
    "features/teams/constants.ts",
    "lib/constants.ts",
    "lib/music-theory.ts",
    "lib/utils.ts",
    "lib/supabase/apply-context-filter.ts",
    "lib/supabase/client.ts",
    "lib/supabase/constants.ts",
    "lib/supabase/server.ts",
    "proxy.ts",
    "!**/*.d.ts",
    "!**/node_modules/**",
    "!**/.next/**",
    "!**/coverage/**",
    "!**/*.config.js"
  ],
  coveragePathIgnorePatterns: [
    "/node_modules/",
    "/.next/",
    "<rootDir>/app/(?!auth/callback/route\\.ts)",
    "<rootDir>/components/",
    "<rootDir>/features/.*/components/",
    "<rootDir>/features/.*/contexts/",
    "<rootDir>/features/.*/types/",
    "<rootDir>/features/.*/index\\.ts$",
    "<rootDir>/features/.*/api/index\\.ts$",
    "<rootDir>/features/.*/api/.*Api\\.ts$",
    "<rootDir>/features/.*/hooks/index\\.ts$",
    "<rootDir>/features/.*/hooks/use-",
    "<rootDir>/lib/actions/",
    "<rootDir>/lib/env\\.ts$",
    "<rootDir>/lib/i18n/",
    "<rootDir>/lib/supabase/database\\.types\\.ts$"
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },

  transform: {
    "^.+\\.(js|jsx|ts|tsx)$": ["babel-jest", { presets: ["next/babel"] }]
  },
  transformIgnorePatterns: [
    "/node_modules/(?!(@uidotdev/usehooks)/)"
  ]
}

// createJestConfig is exported this way to ensure that next/jest can load the Next.js config which is async
module.exports = createJestConfig(customJestConfig)
