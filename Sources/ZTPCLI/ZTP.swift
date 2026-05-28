import ArgumentParser

@main
struct ZTP: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ztp",
        abstract: "Zyquo Tool Protocol — Native Agent Runtime",
        version: "0.1.0",
        subcommands: [
            ToolsCommand.self,
            RunCommand.self,
            ValidateCommand.self,
            InspectCommand.self,
            SchemaCommand.self,
            DoctorCommand.self,
            VersionCommand.self,
            ExcelCommand.self,
            DocxCommand.self,
            SlidesCommand.self,
            ChartCommand.self,
            MailCommand.self,
            MessageCommand.self,
        ],
        defaultSubcommand: VersionCommand.self
    )
}
