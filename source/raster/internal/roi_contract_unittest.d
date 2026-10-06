module raster.internal.roi_contract_unittest;

version (unittest)
{

import raster.descriptor :
    PlaneDescriptor;

import raster.region :
    Region2D;

import raster.resource :
    ResourceAccess,
    ResourceEntry;

import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import raster.view :
    makeRasterViewAssumeValidated;

import raster.writable_view :
    tryMakeWritableRasterView;


/++
    M1.4 executable contract:
    nested ROI translation is equivalent to direct composition when all
    intermediate regions are representable and contained.
+/
@safe
unittest
{
    ubyte[20] samples;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            samples.ptr,
            5,
            1
        )
    ];

    auto root =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                10,
                20,
                5,
                4
            )
        );

    bool firstSuccess;
    bool secondSuccess;
    bool directSuccess;

    auto first =
        root.tryRoi(
            Region2D(
                1,
                1,
                4,
                3
            ),
            firstSuccess
        );

    auto nested =
        first.tryRoi(
            Region2D(
                2,
                1,
                2,
                2
            ),
            secondSuccess
        );

    auto direct =
        root.tryRoi(
            Region2D(
                3,
                2,
                2,
                2
            ),
            directSuccess
        );

    assert(firstSuccess);
    assert(secondSuccess);
    assert(directSuccess);

    assert(
        nested.region
        == Region2D(
            13,
            22,
            2,
            2
        )
    );

    assert(nested.region == direct.region);
}


/++
    M1.4 executable contract:
    zero-area children are valid exactly at contained one-past boundaries.
+/
@safe
unittest
{
    const parent =
        Region2D(
            100,
            200,
            4,
            3
        );

    Region2D resolved;

    assert(
        parent.tryResolveRelative(
            Region2D(
                4,
                3,
                0,
                0
            ),
            resolved
        )
    );

    assert(
        resolved
        == Region2D(
            104,
            203,
            0,
            0
        )
    );

    assert(
        !parent.tryResolveRelative(
            Region2D(
                5,
                3,
                0,
                0
            ),
            resolved
        )
    );

    assert(resolved == Region2D.init);

    assert(
        !parent.tryResolveRelative(
            Region2D(
                4,
                4,
                0,
                0
            ),
            resolved
        )
    );

    assert(resolved == Region2D.init);
}


/++
    M1.4 executable contract:
    an empty parent may contain only geometrically contained empty children.
+/
@safe
unittest
{
    const parent =
        Region2D(
            size_t.max,
            7,
            0,
            2
        );

    Region2D resolved;

    assert(
        parent.tryResolveRelative(
            Region2D(
                0,
                0,
                0,
                2
            ),
            resolved
        )
    );

    assert(
        resolved
        == Region2D(
            size_t.max,
            7,
            0,
            2
        )
    );

    assert(
        !parent.tryResolveRelative(
            Region2D(
                1,
                0,
                0,
                0
            ),
            resolved
        )
    );

    assert(resolved == Region2D.init);
}


/++
    M1.4 executable contract:
    ROI creation preserves signed-stride interpretation and performs no
    layout normalization.
+/
@safe
unittest
{
    ubyte[12] samples;

    foreach (index; 0 .. samples.length)
    {
        samples[index] =
            cast(ubyte) index;
    }

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            samples.ptr + 11,
            -4,
            -1
        )
    ];

    auto parent =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                4,
                3
            )
        );

    bool success;

    auto child =
        parent.tryRoi(
            Region2D(
                1,
                1,
                2,
                2
            ),
            success
        );

    assert(success);
    assert(child.region == Region2D(1, 1, 2, 2));

    ubyte value;

    assert(
        child.trySample(
            0,
            0,
            0,
            value
        )
    );

    /*
     * descriptor base index 11
     * absolute y=1 -> -4
     * absolute x=1 -> -1
     * final physical index = 6
     */
    assert(value == 6);

    assert(
        child.trySample(
            0,
            1,
            1,
            value
        )
    );

    /*
     * absolute y=2 -> -8
     * absolute x=2 -> -2
     * final physical index = 1
     */
    assert(value == 1);
}


/++
    M1.4 executable contract:
    overlapping read-only ROIs remain aliases of the same backing.
+/
@safe
unittest
{
    ubyte[8] samples =
    [
        10, 11, 12, 13,
        20, 21, 22, 23
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            samples.ptr,
            4,
            1
        )
    ];

    auto parent =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                4,
                2
            )
        );

    bool leftSuccess;
    bool rightSuccess;

    auto left =
        parent.tryRoi(
            Region2D(
                0,
                0,
                3,
                2
            ),
            leftSuccess
        );

    auto right =
        parent.tryRoi(
            Region2D(
                1,
                0,
                3,
                2
            ),
            rightSuccess
        );

    assert(leftSuccess);
    assert(rightSuccess);

    ubyte fromLeft;
    ubyte fromRight;

    assert(left.trySample(0, 1, 1, fromLeft));
    assert(right.trySample(0, 0, 1, fromRight));

    assert(fromLeft == 21);
    assert(fromRight == 21);
}


/++
    M1.4 executable contract:
    writable certification is established at the parent boundary and is
    inherited by contained ROIs. Overlapping writable ROIs remain aliases;
    ROI creation establishes no uniqueness or noalias promise.
+/
@safe
unittest
{
    ubyte[8] samples;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            samples.ptr,
            samples.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            samples.ptr,
            4,
            1
        )
    ];

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto parent =
        tryMakeWritableRasterView!ubyte(
            resources[],
            descriptors[],
            Region2D(
                0,
                0,
                4,
                2
            ),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    bool leftSuccess;
    bool rightSuccess;

    auto left =
        parent.tryRoi(
            Region2D(
                0,
                0,
                3,
                2
            ),
            leftSuccess
        );

    auto right =
        parent.tryRoi(
            Region2D(
                1,
                0,
                3,
                2
            ),
            rightSuccess
        );

    assert(leftSuccess);
    assert(rightSuccess);

    assert(
        left.trySetSample(
            0,
            1,
            1,
            91
        )
    );

    ubyte observed;

    assert(
        right.trySample(
            0,
            0,
            1,
            observed
        )
    );

    assert(observed == 91);
}


/++
    M1.4 executable contract:
    failed ROI creation is deterministic and side-effect free.
+/
@safe
unittest
{
    ubyte[8] samples =
    [
        1, 2, 3, 4,
        5, 6, 7, 8
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            samples.ptr,
            4,
            1
        )
    ];

    auto parent =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                4,
                2
            )
        );

    bool success = true;

    auto invalid =
        parent.tryRoi(
            Region2D(
                3,
                1,
                2,
                1
            ),
            success
        );

    assert(!success);
    assert(invalid.region == Region2D.init);
    assert(invalid.planeCount == 0);
    assert(invalid.empty);

    ubyte value;

    assert(parent.trySample(0, 3, 1, value));
    assert(value == 8);
}

} // version (unittest)
