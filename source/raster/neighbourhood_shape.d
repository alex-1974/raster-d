/++
    Compile-time fixed neighbourhood geometry.

    Width, height and anchor are type-level semantics. No runtime shape object is
    required by consumers.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.neighbourhood_shape;


/++
    Fixed neighbourhood geometry with one explicit anchor.

    Width and Height must be non-zero.

    AnchorX and AnchorY identify the output sample position inside the
    neighbourhood:

        0 <= AnchorX < Width
        0 <= AnchorY < Height

    The derived margins are:

        left   = AnchorX
        right  = Width  - AnchorX - 1
        top    = AnchorY
        bottom = Height - AnchorY - 1

    sampleCount is Width * Height and must fit size_t.

    This type intentionally stores no runtime fields. The geometry exists only
    as compile-time enum members and is intended to be passed as a template
    argument to fixed-shape spatial operations.

    No default anchor is inferred. Even-sized and asymmetric neighbourhoods are
    therefore never assigned a hidden center.
+/
struct NeighbourhoodShape(
    size_t Width,
    size_t Height,
    size_t AnchorX,
    size_t AnchorY
)
{
    static assert(
        Width != 0,
        "Neighbourhood width must be non-zero."
    );

    static assert(
        Height != 0,
        "Neighbourhood height must be non-zero."
    );

    static assert(
        AnchorX < Width,
        "Neighbourhood anchor x must lie inside width."
    );

    static assert(
        AnchorY < Height,
        "Neighbourhood anchor y must lie inside height."
    );

    static assert(
        Width <= size_t.max / Height,
        "Neighbourhood sample count must fit size_t."
    );


    enum size_t width =
        Width;

    enum size_t height =
        Height;

    enum size_t anchorX =
        AnchorX;

    enum size_t anchorY =
        AnchorY;

    enum size_t left =
        AnchorX;

    enum size_t right =
        Width - AnchorX - 1;

    enum size_t top =
        AnchorY;

    enum size_t bottom =
        Height - AnchorY - 1;

    enum size_t sampleCount =
        Width * Height;
}


/// Example defining the existing centered 3 x 3 geometry structurally.
@safe unittest
{
    import raster;

    alias Shape =
        NeighbourhoodShape!(
            3,
            3,
            1,
            1
        );

    static assert(Shape.width == 3);
    static assert(Shape.height == 3);
    static assert(Shape.anchorX == 1);
    static assert(Shape.anchorY == 1);

    static assert(Shape.left == 1);
    static assert(Shape.right == 1);
    static assert(Shape.top == 1);
    static assert(Shape.bottom == 1);

    static assert(Shape.sampleCount == 9);
}


version (unittest)
{

alias ThreeByThree =
    NeighbourhoodShape!(
        3,
        3,
        1,
        1
    );

static assert(ThreeByThree.width == 3);
static assert(ThreeByThree.height == 3);
static assert(ThreeByThree.sampleCount == 9);

static assert(ThreeByThree.left == 1);
static assert(ThreeByThree.right == 1);
static assert(ThreeByThree.top == 1);
static assert(ThreeByThree.bottom == 1);


alias FiveByThreeOffCenter =
    NeighbourhoodShape!(
        5,
        3,
        1,
        2
    );

static assert(FiveByThreeOffCenter.width == 5);
static assert(FiveByThreeOffCenter.height == 3);

static assert(FiveByThreeOffCenter.anchorX == 1);
static assert(FiveByThreeOffCenter.anchorY == 2);

static assert(FiveByThreeOffCenter.left == 1);
static assert(FiveByThreeOffCenter.right == 3);
static assert(FiveByThreeOffCenter.top == 2);
static assert(FiveByThreeOffCenter.bottom == 0);

static assert(FiveByThreeOffCenter.sampleCount == 15);


/*
 * Shape semantics are compile-time only.
 *
 * The type contains no instance fields. Generic execution receives Shape as a
 * template argument rather than a runtime descriptor.
 */
static assert(ThreeByThree.tupleof.length == 0);
static assert(FiveByThreeOffCenter.tupleof.length == 0);

} // version (unittest)
