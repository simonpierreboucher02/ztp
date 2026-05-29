import ArgumentParser

@main
struct ZTP: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ztp",
        abstract: "Zyquo Tool Protocol — Native Agent Runtime",
        version: "0.9.0",
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
            BrowserCommand.self,
            MacOSCommand.self,
            OCRCommand.self,
            NotesCommand.self,
            FilesCommand.self,
            FinderCommand.self,
        ],
        defaultSubcommand: VersionCommand.self
    )
}
