/**
 * Compat for Create: Estrogen
 */
if (Platform.isLoaded("estrogen")) {
    console.log("Create: Estrogen found, loading compat scripts...")
    ServerEvents.recipes(event => {
        // Fix uncraftable recipes and those removed by Create compat
        event.shapeless("estrogen:moth_elytra", ["minecraft:elytra", "estrogen:moth_fuzz"])
        event.replaceInput({ id: "estrogen:estrogen_chip_cookie" }, "create:wheat_flour", "gtceu:wheat_dust")
        // ":3"
        event.remove({ output: "estrogen:uwu" }) // TODO: add gregged recipe

        // Fluids
        // TODO

        // Processing lines
        event.remove({ output: "estrogen:centrifuge" }) // We'll use Greg machines
        // TODO: estrogen
        // TODO: testosterone
        // TODO: gender fluid
    })
    console.log("Create: Estrogen compat scripts successfully loaded!")
} else { console.log("Create: Estrogen was not found, skipping its compat scripts.") }
