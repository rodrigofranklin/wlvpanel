### Panel: SETUP

## GLOBAL ----------------

# Carregando lista de idiomas e rótulos
languages <- read.csv2("dados/languages.csv", encoding = "UTF-8")

language_file <- read.csv2(languages$file[1])
for (x in 1:length(languages$language)) {
  l_temp <- read.csv2(languages$file[x], encoding = "UTF-8")
  names(l_temp)[2] <- languages$language[x]
  language_file <- full_join(language_file, l_temp, by = "cod_label")
}
rm(l_temp)
rownames(language_file) <- language_file[,1]
language_file <- language_file[,-c(1,2)]

# Define língua inicial
default_language <- colnames(language_file)[1]

# função label: cria um textOuput de labels
l <- function(lab_code) {
  return(textOutput(paste0("label.",lab_code), inline = TRUE))
}

lb <- function(lab_code,lang){
  
  language_file[lab_code,lang]
}
# Lista de bases
lista_versoes <- names(sea_paises[,1,1,1])
base1 <- "WIOD13"
base2 <- "WIOD16"
base3 <- "EXI382"
base4 <- "WIOD13"

# base1 <- lista_versoes[1]
# base2 <- lista_versoes[2]
# base3 <- lista_versoes[1]
# base4 <- lista_versoes[1]


## UI --------------------

config_panel <- tagList(
  # Config Button
  actionLink(
    "config_button",
    label = NULL,
    style = "
        position: fixed;
        top: 10px;
        right: 10px;
        font-size: 20px;
        color: white;
        z-index: 5000;
      ",
    icon = icon("cog")
  ),
  
  # Config Panel
  conditionalPanel(
    "output.show_config_panel != 0",
    absolutePanel(
      id = "config_background",
      top = 0,
      left = 0,
      right = 0,
      bottom = 0,
      style = "
          background-color: rgba(0, 0, 0, 0.7);
          text-align: center;
          z-index: 5000;
        "
    ),

    actionLink(
      "config_close_button",
      label = NULL,
      style = "
              position: absolute;
              top: 100px;
              left: calc(30vw + 10px);
              z-index: 5000;
              padding: 0px;
              font-size: 14px;
              color: white;
            ",
      # top: calc(50vh - 150px - 20px);
      # right: calc(50vw - 175px + 5px);
      icon = icon("times")
    ),

    absolutePanel(
      # top = "calc(50vh - 150px)",
      # left = "calc(50vw - 175px)",
      top = 120,
      left = 25,
      style = "z-index: 5001;",
      width = "30%",
      # height = 300,
      class="panel panel-default",
      div(
        l("World Labour Value Database - Setup"),
        class = "panel-heading",
        style = "text-align: left;"),
      tags$table(
        width = "100%",
        tags$tr(
          tags$td(
            width = "30%",
            height = "25px",
            style = "padding-bottom: 15px !important; vertical-align:middle; font-weight: bold",
            l("Language")
          ),
          tags$td(
            width = "70%",
            style = "padding: 0px; vertical-align: middle;",
            selectInput(
              inputId = "l",
              label = NULL,
              choices = languages[,1],
              width = "100%")
          ),
          tags$tr(
            tags$td(
              colspan = 2,
              style = "padding: 0px 0px; height: 5",
              tags$hr(style="margin: 5px !important")
            )
          ),
          tags$tr(
            tags$td(
              colspan = 2,
              tags$table( 
                width = "100%",
                height = "100%",
                tags$tr(
                  tags$td(
                    width = "20%",
                    tags$table( 
                      tags$tr(
                        tags$td(l("Bases"))
                      ),
                      tags$tr(
                        tags$td(actionButton("info_bases", label = l("Bases Info")))
                      )
                    )
                  ),
                  tags$td(
                    width = "80%",
                    style = "padding-left: 20px;",
                    tags$table( 
                      width = "100%",
                      tags$tr(
                        tags$td(
                          width = "20%",
                          l("Base 1")
                        ),
                        tags$td(
                          style = "padding-left: 20px;",
                          width = "80%",
                          selectInput(
                            "base1",
                            label = NULL,
                            width = "100%",
                            choices = lista_versoes,
                            selected = base1
                          )
                        )
                      ),
                      tags$tr(
                        tags$td(
                          l("Base 2")
                        ),
                        tags$td(
                          style = "padding-left: 20px;",
                          selectInput(
                            "base2",
                            label = NULL,
                            width = "100%",
                            choices = lista_versoes,
                            selected = base2
                          )
                        )
                      ),
                      tags$tr(
                        tags$td(
                          l("Base 3")
                        ),
                        tags$td(
                          style = "padding-left: 20px;",
                          selectInput(
                            "base3",
                            label = NULL,
                            width = "100%",
                            choices = lista_versoes,
                            selected = base3
                          )
                        )
                      ),
                      tags$tr(
                        tags$td(
                          l("Base 4")
                        ),
                        tags$td(
                          style = "padding-left: 20px;",
                          selectInput(
                            "base4",
                            label = NULL,
                            width = "100%",
                            choices = lista_versoes,
                            selected = base4
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      ) %>% div(
        class = "panel-body",
        style = "text-align: center;")
    ) 
  ),
  
  # Bases_info_panel
  conditionalPanel(
    "output.show_bases_info_panel !=1",
    
    absolutePanel(
      # top = "calc(50vh - 30vh)",
      # left = "calc(50vw - 30vw)",
      # width = "60vw",
      # height = "60vh",
      top = "60px",
      left = "calc(30vw + 45px)",
      width = "40vw",
      class="panel panel-default",
      style = "z-index: 5000;",
      div(class = "panel-heading",
          l("TITLE.bases_info"),
          actionLink(
            "bases_info_close_button",
            label = NULL,
            top = 5,
            right = 5,
            style = "
              position: absolute;
              top: 5px;
              right: 10px;
              padding: 0px;
              font-size: 14px;
              color: gray;
            ",
            icon = icon("times")
          )
      ),
      
      div(class = "panel-body",
          uiOutput("bases_info_text"),
          style =  "
            overflow-y:scroll;
            height: 60vh;
          ")
    ) 
  ) # FIM indicator_info_panel
)

## SERVER --------------------

panel_setup_server <- function(IP, OP) {
  
  # Open/close system
  show_config_panel <- reactiveVal(0)
  OP$show_config_panel <- reactive(show_config_panel())
  outputOptions(OP,"show_config_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$config_button,show_config_panel(1))
  observeEvent(IP$config_close_button, {
    show_config_panel(0)
    show_bases_info_panel(1)
  })
  onclick(id = "config_background", {
    show_config_panel(0)
    show_bases_info_panel(1)
    })
  
  # Labels e traduções
  lapply(rownames(language_file), function(i) {
    OP[[paste0("label.",i)]] <- renderText(language_file[i, IP$l])
  })
  
  # Info bases
  # Open/close system for bases_info_panel
  show_bases_info_panel <- reactiveVal(1)
  OP$show_bases_info_panel <- renderText(show_bases_info_panel())
  outputOptions(OP,"show_bases_info_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$bases_info_close_button, show_bases_info_panel(show_bases_info_panel()*-1))
  observeEvent(IP$info_bases, show_bases_info_panel(show_bases_info_panel()*-1))
  
  OP$bases_info_text <- renderUI({
    tagList(
      lapply(lista_versoes, function(i) {
        tagList(
          p(strong(paste0(i,": ")),
            l(paste0("DESC.",i)),
            style = "text-align: justifY;")
        )
      })
    )
  })
}

