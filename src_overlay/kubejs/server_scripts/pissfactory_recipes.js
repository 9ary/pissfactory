ServerEvents.recipes(event => {
    // Match lapis gear recipe with the other crystal gears
    event.remove({ id: "gtceu:shaped/gear_lapis" })
    event.recipes.gtceu.extruder("kubejs:lapis_gear")
        .itemInputs("4x minecraft:lapis_lazuli")
        .itemOutputs("gtceu:lapis_gear")
        .notConsumable("gtceu:gear_extruder_mold")
        .duration(80)
        .EUt(56)

    // Thermal => Ender IO XP fluid conversion
    event.recipes.gtceu.chemical_reactor("kubejs:cofh_xp_to_enderio")
        .inputFluids("cofh_core:experience 20")
        .notConsumable("enderio:experience_rod")
        .outputFluids("enderio:xp_juice 20")
        .duration(1)
        .EUt(8)
})
