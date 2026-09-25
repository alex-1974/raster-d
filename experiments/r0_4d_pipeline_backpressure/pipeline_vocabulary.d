module pipeline_vocabulary;


/++
    R0.4d research-local stage vocabulary.

    This enum names the states needed to discuss staged raster execution.

    R0.4d-0 deliberately defines no transition function or scheduler.
+/
enum PipelineStage : ubyte
{
    notAdmitted,
    materializing,
    readyForCompute,
    computing,
    completed,
    released
}


/++
    R0.4d research-local count limits.

    These names are vocabulary only in R0.4d-0.

    Their behavioural invariants are proved in later slices.
+/
struct PipelineLimits
{
    size_t maxActiveWorkUnits;
    size_t maxMaterializing;
    size_t maxComputing;
    size_t handoffCapacity;
}


/*
 * Vocabulary identity is explicit and stable inside the experiment.
 *
 * This is not a public ABI promise.
 */
unittest
{
    static assert(
        PipelineStage.notAdmitted
        != PipelineStage.materializing
    );

    static assert(
        PipelineStage.materializing
        != PipelineStage.readyForCompute
    );

    static assert(
        PipelineStage.readyForCompute
        != PipelineStage.computing
    );

    static assert(
        PipelineStage.computing
        != PipelineStage.completed
    );

    static assert(
        PipelineStage.completed
        != PipelineStage.released
    );


    const limits =
        PipelineLimits(
            4,
            2,
            2,
            2
        );


    assert(limits.maxActiveWorkUnits == 4);
    assert(limits.maxMaterializing == 2);
    assert(limits.maxComputing == 2);
    assert(limits.handoffCapacity == 2);
}
