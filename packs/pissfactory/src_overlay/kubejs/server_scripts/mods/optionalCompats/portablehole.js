/**
 * Compat for Portable Hole
 */
if (Platform.isLoaded('portablehole')) {
    console.log("Portable Hole found, loading compat scripts...")
    ServerEvents.recipes(event => {

        // Portable Hole
        event.shaped('portablehole:portable_hole', [
            ' C ',
            'CPC',
            ' C ',
        ], {
            P: 'minecraft:ender_pearl',
            C: 'enderio:pulsating_crystal',
        })
    })
    console.log("Portable Hole compat scripts successfully loaded!")
} else { console.log("Portable Hole was not found, skipping its compat scripts.") }
