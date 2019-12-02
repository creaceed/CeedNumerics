# CeedNumerics

## Numerical Computation in Swift

CeedNumerics is a numerical representation and computation library written in Swift. It defines arbitrarily sized vector, matrix, and tensor types as well as implementation of abstractions and common methods for operating on those types. Inspired by NumPy and other similar numerical packages, it has been modeled to take advantage of Swift's strong typing and other unique language features.

```
import Numerics

let mat: NMatrixd = .init([1.0, 2.0],
						  [1.0,-3.0])
let vec: NVectord = .init([0.5,-1.0])

let res: NVectord = mat.transposed() * vec
```

Numerical computation is everywhere nowadays: in machine learning, but also in computer vision and in other everyday algorithms. Offering a lightweight library that serves as a building block for operating on data without the requirement of linking against large/comprehensive machine learning frameworks is among CeedNumerics intended goals. Additional capabilities and interoperation with other frameworks can be built as layers on top of this foundation in a modular fashion.

## Memory Model, Slicing, and Subscripting

CeedNumerics proposes an abstraction for dimensional types that is different from Swift arrays in that it does *not* rely on copy-on-write (CoW). This is made so to offer both manual control on allocations, which can be very large, and to offer practical and efficient shared "views" on the same underlying data. The representation of dimensional types is closer to Swift's MutablePointer with some additional metadata on how to traverse memory. This is discussed in more details in the Swift forums. 

Interacting with data with simple yet powerful syntax is at the core of the library. A slice allows to access a subset of a larger variable by specifying both a range and a stride for each dimension. In 2D (matrix), it looks like this, where matrix B is defined as a slice of matric A:

<p align="center"><img src="https://user-images.githubusercontent.com/369828/69978689-2ebbe980-152d-11ea-857e-831dfc594843.png" width="75%"></p>

The '~' is used as the more classical ':' is not available at this time in Swift.

The matrix slice is defined in terms of a row slice and a column slice, and the resulting matrix B references the same underlying data as A. Slices can be partially defined (without an end, for instance: `2~~3`) and are resolved when used.

Deriving a standalone and compact data from matrix B (that will not refer to matrix A contents) is achieved with the `copy()` function, which allocates new storage.

## Type Hierarchy & API Design

All dimensional types (vector, matrix, tensor) are lightweight structs that implement the NDimensionalArray protocol, which provides the foundation for the common traits shared by these types. The dimensional types themselves augment this representation by defining what is specific to them. For instance, the row and column semantics is defined on the matrix type, and so is the matrix/vector product.

About API design, many operations are not defined on the types themselves but under a common namespace, Numerics. This is made for 3 reasons: 1. methods can be easier to find (completion), 2. it  avoids giving specific meaning to one of the variables involved in a call (no "receiver": `Numerics.add(a, b)` vs `a.add(b)`), 3. it enables, as opposed to protocol-defined static funcs, to avoid having the same function on different types (`Numerics.addOne()` vs `Matrix.addOne()` & `Vector.addOne()`). 

Functions that compute results stored in a dimensional types have their "reference" implementation that takes the pre-allocated result as argument  (in-place possible), to enable controlling allocations (`multiply(_ a: Matrix, _ b: Vector, _ result: Vector)`). A separate variant of the function that will allocate the result, whose implementation relies on the reference one, is typically proposed as well (`multiply(_ a: Matrix, _ b: Vector) -> Vector`, see also the `_deriving()` function).

## Using CeedNumerics

You need to set this package as a dependency of your own package or Xcode project, and just add `import Numerics` at the top of your Swift file.

Even though CeedNumerics defines all of its dimensional types as generics (for instance: `NMatrix<Double>` or `NMatrix<Float>`, and their respective aliases, `NMatrixd` and `NMatrixf`), we have found out in our own frameworks that it was often better not to propagate the generics capability for APIs built using it but instead pick a type that is appropriate for the task. This makes it easier to write/maintain code (small abstraction layer) and it is faster to compile. 

For instance, in our CeedColorimetry and CeedOCR libraries, we start off with these definitions:

```
public typealias ColorScalar = Double
public typealias ColorMatrix = NMatrix<ColorScalar>
public typealias ColorTemperature = ColorScalar
```

```
public typealias OcrScalar = Double
public typealias OcrMatrix = NMatrix<OcrScalar>
```

## SIMD Acceleration

SIMD (single instruction, multiple data) acceleration is implemented on top of the Accelerate framework for Apple platforms. Other platforms could also get acceleration from other libraries (PR welcome).

CeedNumerics proposes an API to enumerate contents of arbitrary dimensions as linear chunks with constant stride that can be accelerated (`stride = 1` is certainly best). Under certain conditions, these chunks can be coalesced across dimensions into larger entities for more efficient processing. (see the `coalescable` property and `withLinearizedAccesses` function).


## Swift Numerics, Related Projects, and Discussion.

Even though we are using CeedNumerics in our own apps, CeedNumerics is probably not as polished nor as exhaustive as it should be. We wanted to share it in its current state because of the recently announced Swift Numerics initiative. CeedNumerics is not a competitor to Swift Numerics but rather a realization of specific, possibly unusual, design choices that can inspire/challenge/contribute to Swift Numerics by providing code, ideas, and a test bed for experimentation. This will hopefully push forward numerical computation with Swift.

Swift Numerics Links
- Announcement: https://swift.org/blog/numerics
- Swift Forums: 

These other projects propose alternate representations:
- Surge: https://github.com/Jounce/Surge
- Upsurge: https://github.com/alejandro-isaza/Upsurge 
- Swix: https://github.com/stsievert/swix 

Another remark is that the types defined in CeedNumerics model arbitrarily sized dimensional entities. To be complete and also to offer better performance (stack allocation), another kind of types is needed to model the fixed-size entities (think `Vec4<Double>`).

Feedback and contributions are welcome.

