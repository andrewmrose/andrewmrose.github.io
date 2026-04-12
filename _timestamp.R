# Reusable timestamp footer for all pages
htmltools::tags$p(
  paste0(
    "Last updated ",
    format(Sys.time(), "%d %B %Y, %H:%M", tz = "America/Halifax"),
    " (Atlantic)."
  ),
  style = "font-size:0.75rem;color:#6c757d;text-align:center;margin-top:2.5rem;margin-bottom:0;"
)