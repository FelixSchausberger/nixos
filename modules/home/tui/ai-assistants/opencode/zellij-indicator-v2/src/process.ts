import { execFile } from "node:child_process"

export type CommandResult = {
  exitCode: number
  stdout: string
}

export function runCommand(command: string, args: string[]): Promise<CommandResult> {
  return new Promise((resolve) => {
    execFile(command, args, { encoding: "utf8", maxBuffer: 4 * 1024 * 1024, timeout: 5000 }, (error, stdout) => {
      resolve({
        exitCode: error ? (typeof error.code === "number" ? error.code : 1) : 0,
        stdout,
      })
    })
  })
}
