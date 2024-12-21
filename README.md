> [!NOTE]
> Forked to maintain compatibility with the current Haskell ecosystem.
>
> To use, include   `HSoM ^>=1.0` in the project (build) dependencies of the `.cabal` file
> and create a `cabal.project` file in the project's root with the following content
> to override the package. Depending on what you want to do, you'll probably need to override Euterpea as well.
>
> ```
> packages: .
>
> source-repository-package
>    type: git
>    location: https://github.com/ninioArtillero/HSoM
>    tag: master
>
> source-repository-package
>    type: git
>    location: https://github.com/ninioArtillero/Euterpea2
>    tag: master
> ```
> See the
> [Cabal documentation](https://cabal.readthedocs.io/en/stable/cabal-project-description-file.html#specifying-packages-from-remote-version-control-locations)
> for details.


Library to accompany the Haskell School of Music textbook.
See License file for licensing information.
Send questions/comments to Donya Quick (donyaquick@gmail.com).
