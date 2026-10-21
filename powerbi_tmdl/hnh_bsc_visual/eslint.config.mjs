import powerbiVisualsConfigs from "eslint-plugin-powerbi-visuals";

export default [
    powerbiVisualsConfigs.configs.recommended,
    {
        ignores: ["dev/out/**", "node_modules/**", "dist/**", ".vscode/**", ".tmp/**"],
    },
];