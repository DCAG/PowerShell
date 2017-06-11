@{
    AllNodes =
    @(
        @{
            NodeName    = 'VM-1'
            Role        = 'WebDAV'
            WebApps     = @(
                @{
                    AppName   = 'DAV01'
                    AppFolder = 'D:\WebDAVShare\DAV01'
                    WebDAVAuthoringRules = @(
                        @{
                            users  = '*'
                            roles  = ''
                            path   = ''
                            access = ''
                        },
                        @{
                            users  = ''
                            roles  = ''
                            path   = ''
                            access = ''
                        }
                    ) # WebDAVAuthoringRules <END>
                },
                @{
                    AppName   = 'AppDAV02'
                    AppFolder = 'D:\WebDAVShare\DAV02'
                    WebDAVAuthoringRules = @(
                        @{
                            users  = ''
                            roles  = ''
                            path   = ''
                            access = ''
                        }
                    ) # WebDAVAuthoringRules <END>
                }
            ) # WebApps <END>
        },

        @{
            NodeName    = 'VM-2'
            Role        = 'WebDAV'
            WebApps     = @(
                @{
                    AppName   = 'DAV01'
                    AppFolder = 'D:\WebDAVShare\DAV01'
                    WebDAVAuthoringRules = @(
                        @{
                            users  = ''
                            roles  = ''
                            path   = ''
                            access = ''
                        },
                        @{
                            users  = ''
                            roles  = ''
                            path   = ''
                            access = ''
                        }
                    ) # WebDAVAuthoringRules <END>
                }
            ) # WebApps <END>
        }
    ) # AllNodes <END>
}