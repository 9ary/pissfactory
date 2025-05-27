{ ... }:
finalLib: prevLib:
let
  inherit (builtins) addErrorContext;
  inherit (finalLib.attrsets)
    attrByPath
    attrNames
    defaultPackageArgTo
    showAttrPath
    ;
  inherit (finalLib.lists) concatMap;
  inherit (finalLib.trivial) isNull null throwIf;

  /**
    Call a function for each attribute in the given set and return
    the concatenated results.

    # Inputs

    `f`

    : A function, given an attribute's name and value, returns a list of new values.

    `attrs`

    : Attribute set to map over.

    # Type

    ```
    # FIXME
    concatMapAttrsToList :: (String -> a -> b) -> AttrSet -> [b]
    ```

    # Examples
    :::{.example}
    ## `lib.attrsets.concatMapAttrsToList` usage example

    ```nix
    concatMapAttrsToList (name: value: [ name (name + value) ])
       { x = "a"; y = "b"; }
    => [ "x" "xa" "y" "yb" ]
    ```

    :::
  */
  lib.attrsets.concatMapAttrsToList =
    f: attrs: concatMap (name: f name attrs.${name}) (attrNames attrs);

  /**
    Return the value of a package argument, or a default value if the argument
    is missing or null.

    Adds context to traces.

    # Inputs

    `attrPathForPackage`
    : The path of the package (usable for splicing) or null

    `packageArgs`
    : The attribute set for package arguments

    `default`
    : The value to use if `packageArg` is null

    `attrPathForPackageArg`
    : The path of `packageArg` in `packageArgs` (see `lib.attrsets.attrByPath`)

    # Type

    ```
    lib.attrsets.defaultPackageArgTo :: (AttrPath String | Null) -> { ${name :: a} :: b | Null; ... :: Any } -> c -> AttrPath a -> (b | c)
    ```

    # Examples
    :::{.example}
    ## `lib.attrsets.defaultPackageArgTo` usage example

    ```nix
    let
      helloPackageFunction = args@{ attrPathForPackage ? null, lib, stdenv, ... }:
        let
          defaultPackageArgTo' = defaultPackageArgTo args.attrPathForPackage or null args;
          attrPathForPackage = defaultPackageArgTo' [ "hello" ] [ "attrPathForPackage" ];
        in
        stdenv.mkDerivation (finalAttrs: …);
    in
    {
      hello = callPackage helloPackageFunction { attrPathForPackage = [ "hello" ]; };
    }
    ```

    :::
  */
  lib.attrsets.defaultPackageArgTo =
    attrPathForPackage: packageArgs: default: attrPathForPackageArg:
    let
      contextMsgSuffixForPackage =
        if isNull attrPathForPackage then "" else " for package `${showAttrPath attrPathForPackage}`";
      packageArg = attrByPath attrPathForPackageArg null packageArgs;
      shownAttrPathForPackageArg = showAttrPath attrPathForPackageArg;
    in
    addErrorContext
      "while evaluating the package argument `${shownAttrPathForPackageArg}`${contextMsgSuffixForPackage}"
      (
        if isNull packageArg then
          addErrorContext "while evaluating the default value of package argument `${shownAttrPathForPackageArg}`${contextMsgSuffixForPackage}" default
        else
          packageArg
      );

  /**
    Return the value of a package argument, or throw if the argument is missing
    or null.

    Useful when a package arugment is conditionally optional.

    Adds context to traces. The first two arguments match
    `lib.attrsets.defaultPackageArgTo`.

    # Inputs

    `attrPathForPackage`
    : The path of the package (usable for splicing) or null

    `packageArgs`
    : The attribute set for package arguments

    `attrPathForPackageArg`
    : The path of `packageArg` in `packageArgs` (see `lib.attrsets.attrByPath`)

    # Type

    ```
    lib.attrsets.requirePackageArg :: (AttrPath String | Null) -> { ${name :: a} :: b | Null; ... :: Any } -> AttrPath a -> b
    ```

    :::
  */
  lib.attrsets.requirePackageArg =
    attrPathForPackage: packageArgs:
    let
      defaultPackageArgTo' = defaultPackageArgTo attrPathForPackage packageArgs;
    in
    defaultPackageArgTo': attrPathForPackageArg:
    throw "the value of package argument `${showAttrPath attrPathForPackageArg}`${
      if isNull attrPathForPackage then "" else " for package `${showAttrPath attrPathForPackage}`"
    } must not be null";

  lib.trivial.isNull = prevTrivial.isNull or builtins.isNull;

  lib.trivial.null = prevTrivial.null or builtins.null;

  /**
    Like the `assert !(isNull maybeValue); maybeValue` expression, but with a
    custom error message and without the semicolon.

    If non-null, return the identity function, `r: r`.

    If null, throw the error message.

    Calls can be juxtaposed using function application, as `(r: r) a = a`, so
    `(r: r) (r: r) a = a`, and so forth.

    # Inputs

    `maybeValue`
    : Value to check for null

    `msg`
    : Error message on null

    # Type

    ```
    lib.trivial.throwIfNull :: String -> (a | Null) -> a
    ```

    # Examples
    :::{.example}
    ## `lib.trivial.throwIfNull` usage example

    ```nix
    throwIfNull "attribute `foo` must not be null" attrs.foo or null
    ```

    :::
  */
  lib.trivial.throwIfNull = msg: maybeValue: throwIf (isNull maybeValue) msg;

  prevTrivial = prevLib.trivial;
in
builtins.mapAttrs (libModuleName: libModuleUpdate: prevLib.${libModuleName} // libModuleUpdate) lib
