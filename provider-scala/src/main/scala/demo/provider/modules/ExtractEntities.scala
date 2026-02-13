package demo.provider.modules

import cats.effect.IO

import io.constellation.CType
import io.constellation.CValue
import io.constellation.provider.sdk.ModuleDefinition

/** ExtractEntities — regex-based named entity recognition.
  *
  * Input: { text: String } Output: { entities: List<{ name: String, entityType: String }> }
  */
object ExtractEntities {

  // Simple regex patterns for entity extraction
  private val personPattern  = """(?:Mr\.|Mrs\.|Ms\.|Dr\.)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)""".r
  private val orgPattern     = """([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\s+(?:Inc|Corp|LLC|Ltd|Co)""".r
  private val locationPattern = """(?:in|at|from|near)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)""".r

  private val entityRecordType = CType.CProduct(Map(
    "name"       -> CType.CString,
    "entityType" -> CType.CString
  ))

  val module: ModuleDefinition = ModuleDefinition(
    name = "ExtractEntities",
    inputType = CType.CProduct(Map("text" -> CType.CString)),
    outputType = CType.CProduct(Map("entities" -> CType.CList(entityRecordType))),
    version = "1.0.0",
    description = "Extract named entities (people, organizations, locations) from text",
    handler = { (input: CValue) =>
      IO {
        val text = input match {
          case CValue.CProduct(fields, _) =>
            fields("text") match {
              case CValue.CString(v) => v
              case _                 => throw new RuntimeException("Expected text: String")
            }
          case _ => throw new RuntimeException("Expected CProduct input")
        }

        val entities = scala.collection.mutable.ListBuffer[(String, String)]()

        personPattern.findAllMatchIn(text).foreach(m => entities += ((m.group(1), "PERSON")))
        orgPattern.findAllMatchIn(text).foreach(m => entities += ((m.group(1), "ORGANIZATION")))
        locationPattern.findAllMatchIn(text).foreach(m => entities += ((m.group(1), "LOCATION")))

        // Also extract standalone capitalized phrases as potential entities
        val capitalizedPattern = """(?<!\.\s)(?<=\s|^)([A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,})*)""".r
        capitalizedPattern.findAllMatchIn(text).foreach { m =>
          val name = m.group(1)
          if (!entities.exists(_._1 == name)) {
            entities += ((name, "ENTITY"))
          }
        }

        val entityStructure = Map("name" -> CType.CString, "entityType" -> CType.CString)
        val entityValues = entities.distinct.map { case (name, typ) =>
          CValue.CProduct(
            Map("name" -> CValue.CString(name), "entityType" -> CValue.CString(typ)),
            entityStructure
          )
        }.toVector

        CValue.CProduct(
          Map("entities" -> CValue.CList(entityValues, entityRecordType)),
          Map("entities" -> CType.CList(entityRecordType))
        )
      }
    }
  )
}
