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

        // We'll use Greg machines
        event.remove({ output: "estrogen:centrifuge" })
        event.remove({ type: "estrogen:centrifuging" })

        // Estrogen
        event.recipes.gtceu.mixer("kubejs:filtrated_horse_urine")
            .itemInputs("create:filter")
            .inputFluids("estrogen:horse_urine 250")
            .itemOutputs("estrogen:used_filter")
            .outputFluids("estrogen:filtrated_horse_urine 200")
            .duration(20 * 20).EUt(16)
        event.recipes.gtceu.distillery("kubejs:liquid_estrogen")
            .inputFluids("estrogen:filtrated_horse_urine 1000")
            .outputFluids("estrogen:liquid_estrogen 100")
            .duration(100).EUt(30)
        event.remove({ output: "estrogen:estrogen_pill" })
        // Restore storage block recipe
        event.shapeless("9x estrogen:estrogen_pill", "estrogen:estrogen_pill_block")
        event.recipes.gtceu.autoclave("kubejs:estrogen_pill")
            .itemInputs("minecraft:sugar")
            .inputFluids("estrogen:liquid_estrogen 100")
            .itemOutputs("estrogen:estrogen_pill")
            .duration(30).EUt(30)
        event.remove({ output: "estrogen:estrogen_patches" })
        // Basically the same as a resin circuit board but paper
        event.recipes.gtceu.assembler("kubejs:estrogen_patches")
            .itemInputs("minecraft:paper")
            .inputFluids("gtceu:glue 100")
            .circuit(32)
            .itemOutputs("estrogen:estrogen_patches")
            .duration(150).EUt(7)

        // Filter washing
        event.remove({ input: "estrogen:used_filter" })
        event.recipes.gtceu.ore_washer("wash_used_filter")
            .itemInputs("estrogen:used_filter")
            .inputFluids("minecraft:water 100")
            .itemOutputs("create:filter")
            .duration(20 * 20).EUt(8)
        event.recipes.gtceu.ore_washer("wash_used_filter_distilled_water")
            .itemInputs("estrogen:used_filter")
            .inputFluids("gtceu:distilled_water 100")
            .itemOutputs("create:filter")
            .duration(10 * 20).EUt(8)

        // TODO: testosterone
        // TODO: gender fluid
    })
    console.log("Create: Estrogen compat scripts successfully loaded!")
} else { console.log("Create: Estrogen was not found, skipping its compat scripts.") }
