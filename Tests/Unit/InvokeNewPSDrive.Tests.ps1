function Invoke-NewPSDrive {
    param ()

    $testUserName = 'TestUsername'
    $secureTestPassword = ConvertTo-SecureString -String 'F@kePassw0rd' -AsPlainText -Force

    $testCredential = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList @( $testUsername, $secureTestPassword )

    $newPSDriveParameters = @{
        Name = [System.Guid]::NewGuid()
        PSProvider = 'FileSystem'
        Root = $env:temp
        Scope = 'Script'
        Credential = $testCredential
    }

    $psDrive = New-PSDrive @newPSDriveParameters
}

Describe 'Invoke-NewPSDrive Test' {
    $mockPSDrive = New-MockObject -Type 'System.Management.Automation.PSDriveInfo'
    Mock -CommandName 'New-PSDrive' -MockWith { return $mockPSDrive }

    It 'Should not throw' {
        { Invoke-NewPSDrive } | Should Not Throw
    }

    It 'Should call New-PSDrive mock' {
        Assert-MockCalled -CommandName 'New-PsDrive' -Exactly 1 -Scope 'Describe'
    }
}