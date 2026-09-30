module raster.internal.residency;


/++
    Package-internal byte budget for explicitly admitted resident raster work.

    This is not a cache policy and does not own raster resources.
+/
package(raster)
struct ResidencyBudget
{
private:
    size_t limitBytes_;

    size_t admittedBytes_;

public:
    package(raster)
    this(size_t limitBytes)
    @safe
    pure
    nothrow
    @nogc
    {
        limitBytes_ =
            limitBytes;
    }


    package(raster)
    @property
    size_t limitBytes() const
    @safe
    pure
    nothrow
    @nogc
    {
        return limitBytes_;
    }


    package(raster)
    @property
    size_t admittedBytes() const
    @safe
    pure
    nothrow
    @nogc
    {
        return admittedBytes_;
    }


    package(raster)
    @property
    size_t availableBytes() const
    @safe
    pure
    nothrow
    @nogc
    {
        assert(admittedBytes_ <= limitBytes_);

        return
            limitBytes_
            - admittedBytes_;
    }


    /++
        Attempts to admit one resident byte obligation.

        Failure leaves the current admitted byte count unchanged.
    +/
    package(raster)
    bool tryAdmit(size_t requiredBytes)
    @safe
    pure
    nothrow
    @nogc
    {
        assert(admittedBytes_ <= limitBytes_);

        if (
            requiredBytes
            > limitBytes_ - admittedBytes_
        )
        {
            return false;
        }

        admittedBytes_ +=
            requiredBytes;

        return true;
    }


    /++
        Releases one previously admitted byte obligation.

        Failure leaves the current admitted byte count unchanged.
    +/
    package(raster)
    bool tryRelease(size_t releasedBytes)
    @safe
    pure
    nothrow
    @nogc
    {
        if (
            releasedBytes
            > admittedBytes_
        )
        {
            return false;
        }

        admittedBytes_ -=
            releasedBytes;

        return true;
    }
}


version (unittest)
{

unittest
{
    ResidencyBudget budget =
        ResidencyBudget(100);

    assert(budget.limitBytes == 100);
    assert(budget.admittedBytes == 0);
    assert(budget.availableBytes == 100);

    assert(budget.tryAdmit(100));
    assert(budget.admittedBytes == 100);
    assert(budget.availableBytes == 0);
}


unittest
{
    ResidencyBudget budget =
        ResidencyBudget(100);

    assert(!budget.tryAdmit(101));
    assert(budget.admittedBytes == 0);
    assert(budget.availableBytes == 100);
}


unittest
{
    ResidencyBudget budget =
        ResidencyBudget(100);

    assert(budget.tryAdmit(40));
    assert(budget.tryAdmit(60));

    assert(budget.admittedBytes == 100);

    assert(!budget.tryAdmit(1));
    assert(budget.admittedBytes == 100);
}


unittest
{
    ResidencyBudget budget =
        ResidencyBudget(100);

    assert(budget.tryAdmit(60));
    assert(budget.tryRelease(20));

    assert(budget.admittedBytes == 40);
    assert(budget.availableBytes == 60);

    assert(budget.tryAdmit(60));
    assert(budget.admittedBytes == 100);
}


unittest
{
    ResidencyBudget budget =
        ResidencyBudget(10);

    assert(budget.tryAdmit(0));
    assert(budget.admittedBytes == 0);

    assert(budget.tryAdmit(7));

    assert(!budget.tryRelease(8));
    assert(budget.admittedBytes == 7);

    assert(budget.tryRelease(0));
    assert(budget.admittedBytes == 7);
}


unittest
{
    ResidencyBudget budget =
        ResidencyBudget(size_t.max);

    assert(budget.tryAdmit(size_t.max));
    assert(budget.admittedBytes == size_t.max);

    assert(!budget.tryAdmit(1));
    assert(budget.admittedBytes == size_t.max);

    assert(budget.tryRelease(size_t.max));
    assert(budget.admittedBytes == 0);
}


unittest
{
    ResidencyBudget budget =
        ResidencyBudget(size_t.max);

    assert(budget.tryAdmit(size_t.max - 1));

    const before =
        budget.admittedBytes;

    assert(!budget.tryAdmit(2));
    assert(budget.admittedBytes == before);
}

} // version (unittest)
