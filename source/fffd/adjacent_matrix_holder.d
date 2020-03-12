module fffd.adjacent_matrix_holder;

import fffd.bit_utils;
import std.conv;

struct Offset
{
    int y, x;
}

class AdjacentMatrixHolder
{

    private ubyte kernelMargin;
    private Bitmask[] matrix;
    private Offset[] offsets;

    private Bitmask originMask;

    this(ubyte kernelMargin) @safe
    {
        this.kernelMargin = kernelMargin;
        int kernelDiameter = kernelMargin + 1 + kernelMargin;
        this.offsets = [];

        const intKernelMargin = to!int(kernelMargin);

        foreach (yo; -intKernelMargin .. (intKernelMargin + 1))
        {
            foreach (xo; -intKernelMargin .. (intKernelMargin + 1))
            {
                Offset offset = {y:
                yo, x : xo};
                this.offsets ~= offset;
            }
        }

        assert((kernelDiameter * kernelDiameter) == offsets.length);

        int origin = (kernelDiameter * kernelDiameter) / 2;
        this.matrix.length = offsets.length;

        assert(this.offsets[origin].y == 0);
        assert(this.offsets[origin].x == 0);

        assert(this.offsets[origin - kernelDiameter].y == -1);
        assert(this.offsets[origin - kernelDiameter].x == 0);

        assert(this.offsets[origin + kernelDiameter].y == 1);
        assert(this.offsets[origin + kernelDiameter].x == 0);

        assert(this.offsets[origin - 1].y == 0);
        assert(this.offsets[origin - 1].x == -1);

        assert(this.offsets[origin + 1].y == 0);
        assert(this.offsets[origin + 1].x == 1);

        foreach (yo; -intKernelMargin .. intKernelMargin)
        {
            foreach (xo; -intKernelMargin .. intKernelMargin)
            {

                int left_top = origin + yo * kernelDiameter + xo;
                int right_top = left_top + 1;
                int left_bottom = left_top + kernelDiameter;
                int right_bottom = left_bottom + 1;

                this.matrix[left_top].setTrue(right_top);
                this.matrix[right_top].setTrue(left_top);

                this.matrix[left_top].setTrue(left_bottom);
                this.matrix[left_bottom].setTrue(left_top);

                this.matrix[right_top].setTrue(right_bottom);
                this.matrix[right_bottom].setTrue(right_top);

                this.matrix[left_bottom].setTrue(right_bottom);
                this.matrix[right_bottom].setTrue(left_bottom);
            }
        }

        assert(this.matrix[0].notZero());

        int offsets_origin = to!int(this.offsets.length) / 2;
        this.originMask.setTrue(offsets_origin);
    }

    const Bitmask getOriginMask() @safe
    {
        // struct copy
        return this.originMask;
    }

    const Offset[] getOffsets() @safe
    {
        return this.offsets.dup;
    }

    const Bitmask getOrResult(in Bitmask thisStepResult) @safe
    {
        Bitmask result;

        foreach (part; 0 .. 2)
        {
            ulong bit = 0b1UL;
            if ((thisStepResult.a[part] & bit) != 0)
            {
                result = or(result, this.matrix[64 * part]);
            }

            foreach (i; 1 .. 64)
            {
                bit *= 2;

                if ((thisStepResult.a[part] & bit) != 0)
                {
                    result = or(result, this.matrix[64 * part + i]);
                }
            }
        }

        return result;
    }
}
