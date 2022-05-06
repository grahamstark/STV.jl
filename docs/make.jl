using STV
using Documenter

DocMeta.setdocmeta!(STV, :DocTestSetup, :(using STV); recursive=true)

makedocs(;
    modules=[STV],
    authors="Graham Stark",
    repo="https://github.com/grahamstark/STV.jl/blob/{commit}{path}#{line}",
    sitename="STV.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://grahamstark.github.io/STV.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/grahamstark/STV.jl",
    devbranch="main",
)
