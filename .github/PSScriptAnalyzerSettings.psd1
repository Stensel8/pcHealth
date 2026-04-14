@{
    # Rules excluded for this project:
    #
    # PSAvoidUsingWriteHost      — CLI tools intentionally use Write-Host for coloured output
    # PSReviewUnusedParameter    — parameters can be used via dynamic dispatch or splatting
    # PSAvoidGlobalVars          — menu scripts share state via module-level globals by design
    # PSUseShouldProcessForStateChangingFunctions — admin tools don't need ShouldProcess
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSReviewUnusedParameter',
        'PSAvoidGlobalVars',
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
