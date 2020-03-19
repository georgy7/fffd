/*
    fffd - edge bunches detection tool.
    Copyright (C) 2020  Georgy Ustinov  <georgy.ustinov.hello@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

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
    private Bitmask notOriginMask;

    private Bitmask originResult;

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

        assert(this.matrix[0].nonZero());

        int offsetsOrigin = to!int(this.offsets.length) / 2;
        this.originMask.setTrue(offsetsOrigin);

        for (int i = 0; i < this.offsets.length; i++)
        {
            if (i != offsetsOrigin)
            {
                this.notOriginMask.setTrue(i);
            }
        }

        this.originResult = this.getOrResultInner(this.originMask);
    }

    const Bitmask getOriginMask() @safe
    {
        // struct copy
        return this.originMask;
    }

    const Bitmask getNotOriginMask() @safe
    {
        // struct copy
        return this.notOriginMask;
    }

    const Offset[] getOffsets() @safe
    {
        return this.offsets.dup;
    }

    const Bitmask getOrResult(in Bitmask thisStepResult) @safe
    {
        if (this.originMask == thisStepResult)
        {
            return this.originResult;
        }

        return getOrResultInner(thisStepResult);
    }

    private const Bitmask getOrResultInner(in Bitmask thisStepResult) @safe
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
