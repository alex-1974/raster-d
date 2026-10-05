module raster.tests.copy_conversion_contract;
// Package-local fixture setup; operations under test use the public API.
import std.meta : AliasSeq;
import std.stdio : writeln;
import raster : Region2D,tryCopyRasterPlane,RasterCopyError,
    tryConvertUbyteToFloatPlane,UbyteToFloatConversionError;
import raster.descriptor : PlaneDescriptor;
import raster.resource : ResourceEntry,ResourceAccess;
import raster.validation : BackingValidationResult,WritableBackingCertificationResult;
import raster.view : RasterView,makeRasterViewAssumeValidated;
import raster.writable_view : WritableRasterView,tryMakeWritableRasterView;
alias ArraySample = uint[2];
struct Pod { uint a; ushort b; ubyte c; ubyte d; }
static assert(Pod.sizeof==8);
private uint bits(float f) @safe nothrow @nogc
{ union U { float f;uint u; } U v;v.f=f;return v.u; }
private float fromBits(uint u) @safe nothrow @nogc
{ union U { float f;uint u; } U v;v.u=u;return v.f; }
private T sample(T)(size_t i)
{
    static if(is(T==ubyte)) return cast(ubyte)(i*37+11);
    else static if(is(T==float)) return fromBits([0u,0x80000000u,0x7fc12345u,
        0x7f800000u,0xff800000u,1u,0x3f800000u,0xbe800000u][i%8]);
    else static if(is(T==ArraySample)) return [cast(uint)(i*17),cast(uint)(i*31)];
    else return Pod(cast(uint)(i*1664525+1013904223),cast(ushort)(i*19),cast(ubyte)i,cast(ubyte)(i*13));
}
private bool identical(T)(T a,T b)
{ static if(is(T==float)) return bits(a)==bits(b); else return a==b; }
private ulong fingerprint(T)(scope const(T)[] data)
{
    ulong hash=0xcbf29ce484222325;
    foreach(v;data){
        static if(is(T==float)) { hash^=bits(v);hash*=0x100000001b3; }
        else static if(is(T==ubyte)) {hash^=v;hash*=0x100000001b3;}
        else static if(is(T==ArraySample)) foreach(n;v){hash^=n;hash*=0x100000001b3;}
        else foreach(n;[ulong(v.a),ulong(v.b),ulong(v.c),ulong(v.d)]){hash^=n;hash*=0x100000001b3;}
    }return hash;
}
private WritableRasterView!T writable(T)(return scope const(ResourceEntry)[] rs,
    return scope const(PlaneDescriptor)[] ds,Region2D region) @safe nothrow @nogc
{
    BackingValidationResult v;WritableBackingCertificationResult c;
    auto target=tryMakeWritableRasterView!T(rs,ds,region,v,c);
    if(!v.ok || !c.ok) assert(0,"invalid writable fixture");return target;
}
private uint publicCall(S,D)(uint path,scope RasterView!S s,size_t si,
    scope ref WritableRasterView!D d,size_t di)
{
    bool ok;uint error;
    static if(is(S==D))
    {
        RasterCopyError e;
        ok=tryCopyRasterPlane(s,si,d,di,e);error=cast(uint)e;
    }
    else
    {
        UbyteToFloatConversionError e;
        ok=tryConvertUbyteToFloatPlane(s,si,d,di,e);error=cast(uint)e;
    }
    if(ok!=(error==0))throw new Exception("bool/error mismatch");return error;
}
private struct Geometry {ptrdiff_t row,sample;size_t offset,length;}
private Geometry geometry(size_t w,size_t h,ptrdiff_t sr,ptrdiff_t sx)
{
    const re=cast(size_t)(sr<0 ? -sr : sr)*(h-1);
    const se=cast(size_t)(sx<0 ? -sx : sx)*(w-1);
    return Geometry(sr,sx,19+(sr<0 ? re : 0)+(sx<0 ? se : 0),19+re+se+1+19);
}
private size_t index(Geometry g,size_t x,size_t y)
{return cast(size_t)(cast(ptrdiff_t)g.offset+cast(ptrdiff_t)y*g.row+cast(ptrdiff_t)x*g.sample);}
private void verifyCase(S,D)(size_t w,size_t h,string layout)
{
    ptrdiff_t sr=cast(ptrdiff_t)(w+32),sx=1,dr=sr,dx=1;
    switch(layout){
        case "contiguous":sr=dr=cast(ptrdiff_t)w;break;
        case "padded":break;
        case "negative-source":sr=-sr;break;
        case "negative-both":sr=-sr;dr=-dr;break;
        case "universal":sx=dx=2;sr=dr=cast(ptrdiff_t)(2*w+32);break;
        case "universal-negative":sx=dx=-2;sr=dr=-cast(ptrdiff_t)(2*w+32);break;
        case "repeated-source":sr=0;break;
        case "zero-source":sr=sx=0;break;
        default:throw new Exception("layout");
    }
    const sg=geometry(w,h,sr,sx),dg=geometry(w,h,dr,dx);
    auto input=new S[sg.length];auto output=new D[dg.length];auto expected=new D[dg.length];
    input[]=sample!S(29);output[]=sample!D(17);expected[]=sample!D(17);
    foreach(y;0..h)foreach(x;0..w)input[index(sg,x,y)]=sample!S(y*w+x);
    foreach(y;0..h)foreach(x;0..w){
        static if(is(S==D))expected[index(dg,x,y)]=input[index(sg,x,y)];
        else expected[index(dg,x,y)]=cast(float)input[index(sg,x,y)];
    }
    const sourceHash=fingerprint!S(input),expectedHash=fingerprint!D(expected);
    const PlaneDescriptor[1] sd=[PlaneDescriptor(input.ptr+sg.offset,sr,sx)];
    const PlaneDescriptor[1] dd=[PlaneDescriptor(output.ptr+dg.offset,dr,dx)];
    const ResourceEntry[1] rs=[ResourceEntry(output.ptr,output.length*D.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!S(sd[],Region2D(0,0,w,h));
    scope auto target=writable!D(rs[],dd[],Region2D(0,0,w,h));
    if(publicCall(0,source,0,target,0)!=0)throw new Exception("public operation failure");
    if(fingerprint!S(input)!=sourceHash)throw new Exception("source/padding changed");
    foreach(i;0..output.length)
        if(!identical(output[i],expected[i]))throw new Exception("destination/padding mismatch");
    if(fingerprint!D(output)!=expectedHash)throw new Exception("output hash");
}

private void contracts(S,D)(uint path)
{
    S[32] a;D[32] b;a[]=sample!S(5);b[]=sample!D(17);const hash=fingerprint!D(b);
    const ResourceEntry[1] rs=[ResourceEntry(b.ptr,b.sizeof,null,null,ResourceAccess.readWrite)];
    const PlaneDescriptor[1] sd=[PlaneDescriptor(a.ptr,4,1)],dd=[PlaneDescriptor(b.ptr,4,1)],nd=[PlaneDescriptor(b.ptr,0,1)];
    scope auto s=makeRasterViewAssumeValidated!S(sd[],Region2D(0,0,4,2));
    scope auto d=writable!D(rs[],dd[],Region2D(0,0,4,2));
    scope auto non=writable!D(rs[],nd[],Region2D(0,0,4,2));
    scope auto wrong=writable!D(rs[],dd[],Region2D(0,0,3,2));
    if(publicCall(path,s,1,d,0)!=1 || publicCall(path,s,0,d,1)!=2 || publicCall(path,s,0,wrong,0)!=3 || publicCall(path,s,0,non,0)!=4)
        throw new Exception("error order/injectivity");
    const PlaneDescriptor[1] overlap=[PlaneDescriptor(b.ptr,cast(ptrdiff_t)(4*D.sizeof/S.sizeof),1)];
    scope auto os=makeRasterViewAssumeValidated!S(overlap[],Region2D(0,0,4,2));
    if(publicCall(path,os,0,d,0)!=5)throw new Exception("overlap accepted");
    if(fingerprint!D(b)!=hash)throw new Exception("failed operation wrote destination");
    const PlaneDescriptor[1] empty=[PlaneDescriptor(null,ptrdiff_t.min,ptrdiff_t.min)];
    scope auto es=makeRasterViewAssumeValidated!S(empty[],Region2D(size_t.max,size_t.max-2,0,2));
    scope auto ed=writable!D(rs[],empty[],Region2D(size_t.max,size_t.max-2,0,2));
    if(publicCall(path,es,0,ed,0)!=0 || publicCall(path,es,1,ed,0)!=1 || publicCall(path,es,0,ed,1)!=2)
        throw new Exception("empty/error contract");
    if(fingerprint!D(b)!=hash)throw new Exception("empty wrote destination");
}
private void sharedBacking(uint path)
{
    // Interleaved ubyte planes have overlapping envelopes but disjoint samples.
    ubyte[128] data;foreach(i;0..data.length)data[i]=sample!ubyte(i);auto expected=data;
    foreach(i;0..32)expected[2*i+1]=data[2*i];
    const PlaneDescriptor[1] sd=[PlaneDescriptor(data.ptr,64,2)],dd=[PlaneDescriptor(data.ptr+1,64,2)];
    const ResourceEntry[1] rs=[ResourceEntry(data.ptr,data.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto s=makeRasterViewAssumeValidated!ubyte(sd[],Region2D(0,0,32,1));
    scope auto d=writable!ubyte(rs[],dd[],Region2D(0,0,32,1));
    if(publicCall(path,s,0,d,0)!=0 || data!=expected)throw new Exception("shared sparse copy");
    // Float-aligned targets occupy bytes 4..7 of each eight-byte cell; ubyte
    // source occupies byte 0. Bounding envelopes overlap; sample bytes do not.
    float[64] storage;auto bytes=(cast(ubyte*)storage.ptr)[0..storage.sizeof];
    foreach(i;0..bytes.length)bytes[i]=cast(ubyte)(i*37);auto expectedBytes=bytes.dup;
    foreach(i;0..16){union U {float value;ubyte[4] representation;}
        U v;v.value=cast(float)bytes[8*i];
        foreach(k;0..4)expectedBytes[8*i+4+k]=v.representation[k];}
    const PlaneDescriptor[1] cs=[PlaneDescriptor(bytes.ptr,0,8)],ct=[PlaneDescriptor(storage.ptr+1,0,2)];
    const ResourceEntry[1] cr=[ResourceEntry(storage.ptr,storage.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto cv=makeRasterViewAssumeValidated!ubyte(cs[],Region2D(0,0,16,1));
    scope auto tv=writable!float(cr[],ct[],Region2D(0,0,16,1));
    if(publicCall(path,cv,0,tv,0)!=0 || bytes!=expectedBytes)throw new Exception("shared sparse conversion");
}
private void sharedCanonicalCopy(T)(uint path)
{
    T[64] storage;foreach(i;0..storage.length)storage[i]=sample!T(i);
    auto expected=storage;
    foreach(y;0..4)foreach(x;0..4)expected[8*y+4+x]=storage[8*y+x];
    const PlaneDescriptor[1] sd=[PlaneDescriptor(storage.ptr,8,1)],dd=[PlaneDescriptor(storage.ptr+4,8,1)];
    const ResourceEntry[1] rs=[ResourceEntry(storage.ptr,storage.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!T(sd[],Region2D(0,0,4,4));
    scope auto target=writable!T(rs[],dd[],Region2D(0,0,4,4));
    if(publicCall(path,source,0,target,0)!=0)throw new Exception("shared Canonical copy rejected");
    foreach(i;0..storage.length)if(!identical(storage[i],expected[i]))throw new Exception("shared Canonical copy backing");
}
private void sharedCanonicalConversion(uint path)
{
    float[64] storage;auto bytes=(cast(ubyte*)storage.ptr)[0..storage.sizeof];
    foreach(i;0..bytes.length)bytes[i]=cast(ubyte)(i*37+11);auto expected=bytes.dup;
    foreach(y;0..4)foreach(x;0..4){
        union U{float value;ubyte[4] representation;}U v;v.value=cast(float)bytes[32*y+x];
        foreach(k;0..4)expected[32*y+4+4*x+k]=v.representation[k];
    }
    const PlaneDescriptor[1] sd=[PlaneDescriptor(bytes.ptr,32,1)],dd=[PlaneDescriptor(storage.ptr+1,8,1)];
    const ResourceEntry[1] rs=[ResourceEntry(storage.ptr,storage.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!ubyte(sd[],Region2D(0,0,4,4));
    scope auto target=writable!float(rs[],dd[],Region2D(0,0,4,4));
    if(publicCall(path,source,0,target,0)!=0 || bytes!=expected)throw new Exception("shared Canonical conversion backing");
}

void run()
{
    foreach(T;AliasSeq!(ubyte,float,Pod,ArraySample))contracts!(T,T)(0);
    contracts!(ubyte,float)(0);sharedBacking(0);
    foreach(T;AliasSeq!(ubyte,float,Pod,ArraySample))sharedCanonicalCopy!T(0);
    sharedCanonicalConversion(0);
    enum layouts=["contiguous","padded","negative-source","negative-both",
        "universal","universal-negative","repeated-source","zero-source"];
    foreach(size;[[31UL,17UL],[256UL,128UL],[2048UL,512UL]])foreach(layout;layouts){
        foreach(T;AliasSeq!(ubyte,float,Pod,ArraySample))verifyCase!(T,T)(size[0],size[1],layout);
        verifyCase!(ubyte,float)(size[0],size[1],layout);
    }
    writeln("PASS public copy/conversion: 120 independent backing cases; error/no-write/empty/shared controls");
}
void main(){run();}
unittest{run();}
