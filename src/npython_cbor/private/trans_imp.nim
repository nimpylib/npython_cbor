
import std/macros
proc dotSlash(id: NimNode): NimNode = prefix(id, "./")
macro impExp*(pre, names) =
  result = newStmtList()
  let imp = infix(pre, "/", names)
  result.add nnkImportStmt.newTree(imp)
  let exp = newNimNode nnkExportStmt
  for name in names:
    exp.add name
  result.add exp
macro impExpCwd*(pre, names) =
  getAst impExp(dotSlash(pre), names)

