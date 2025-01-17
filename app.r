library(shiny); library(leaflet); library(leafpop); library(tidyverse); library(sf)

css = HTML("
  .leaflet-top, .leaflet-bottom {
    z-index: unset !important;
  }
           
    .leaflet-touch .leaflet-control-layers, .leaflet-touch .leaflet-bar {
    z-index: 10000000000 !important;
  }
    #controls{opacity: .5;}
    #controls:hover{opacity: 1;}")

ui <- fluidPage(
  tags$head(tags$style(css)),
  
  headerPanel("Spatiotemporal PM2.5 Cross Validated Model Performance"),
  
  #sidebarLayout(
  # sidebarPanel = sidebarPanel(width = 300,
  absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                  draggable = TRUE, top = 60, left = "auto", right = 20, bottom = "auto",
                  width = 200, height = "auto", style = "z-index: 10;",

      
    radioButtons("temp", "Temporal Resolution", choices = c("All" = "all", 
                                                              "Annual" = "annual", 
                                                              "Monthly" = "monthly", 
                                                              "Weekly" = "weekly", 
                                                              "Daily" = "daily")),
                                                              #"None selected" = "")),
      
    radioButtons("err", "Performance Metric", choices = c("MAE" = "mae",
                                                      "RMSE" = "rmse",
                                                      "R\u00B2" = "rsq",
                                                      #"Slope" = "slope",
                                                      "95% Conf. Int. Coverage" = "ci_coverage"),
                                                      #"None selected" = ""),
                   selected = "mae")
      
      
      
    ), #sidebarPanel absolutePanel
    
   # mainPanel = mainPanel(
    leafletOutput('map', width="100%", height=800),
  
  br(),
  
  p(strong("About:"),"This interactive map illustrates the cross validated performance of a nationwide spatiotemporal PM2.5 exposure assessment model according to 81 different regions corresponding to resolution 2 H3 cells (average area: 86.7 sq km) covering the study domain and different temporal aggregations."),
  p(strong("Citation:"),"Brokamp, C. A High Resolution Spatiotemporal Fine Particulate Matter Exposure Assessment Model for the Contiguous United States. Environmental Advances. In Press. 2021. 2021090164 (doi: 10.1016/j.envadv.2021.100155)"),
  p("Accepted preprint available online at", tags$a(href=" https://doi.org/10.1016/j.envadv.2021.100155", "https://doi.org/10.1016/j.envadv.2021.100155"))
    
  #  ) #mainPanel
 # ) #sidebarLayout
) #fluidPage

server <- function(input, output, session) {
  
  d <- reactive({readRDS("d_map_long.rds")})
  
  d_aqs <- reactive({readRDS("aqs_censors.rds") %>% 
    st_as_sf()
    })
  
  d_user <- reactive({
    d() %>%
      filter(time == input$temp & metric == input$err) %>%
      sf::st_as_sf()
  }) #filter to selections
  
  #d_user <- reactive({sf::st_transform(d_user(), crs = 5072)})

  output$map <- renderLeaflet({
     leaflet(~d_user()) %>%
       setView(-93.65, 38.0285, zoom = 4.5) %>%
       addTiles()  
    
    }) #renderLeaflet

  observe({
    
    #dom <- range(d_user()$value, na.rm = T)
    if(d_user()$metric == 'rsq' & d_user()$time == 'all'){
      pal <- colorNumeric("viridis", domain = c(0:1), na.color = "#F7F7F7") #all/rsq is NA for all, set to grey
    } else{
      pal <- colorNumeric("viridis", domain = d_user()$value)
    }
    
    pal2 <- colorBin("viridis", domain = d_aqs()$count, bins = 5)

      if(d_user()$metric == 'mae'){
        leafletProxy("map", data = d_user()) %>%
          clearShapes() %>%
          clearControls() %>%
          addPolygons(color = ~pal(value), opacity = .75, fillOpacity = .55) %>%
          addPolygons(data = d_aqs(), color = ~pal2(count)) %>% 
          addLegend("bottomright", pal = pal, values = ~value,
                 title = "MAE (μg/m\u00B3)", opacity = .9) %>% 
          addLegend("bottomleft", pal = pal2, values = ~count, bins = 5,
                    title = "Number of Measurements at Monitor", opacity = .9)
      } else if (d_user()$metric == 'rmse'){
        leafletProxy("map", data = d_user()) %>%
          clearShapes() %>%
          clearControls() %>%
          addPolygons(color = ~pal(value), opacity = .75, fillOpacity = .55) %>%
          addPolygons(data = d_aqs(), color = ~pal2(count)) %>%
          addLegend("bottomright", pal = pal, values = ~value,
                 title = "RMSE (μg/m\u00B3)", opacity = .9) %>% 
          addLegend("bottomleft", pal = pal2, values = ~count, bins = 5,
                    title = "Number of Measurements at Monitor", opacity = .9) 
      } else if (d_user()$metric == 'rsq'){
        leafletProxy("map", data = d_user()) %>%
          clearShapes() %>%
          clearControls() %>%
          addPolygons(color = ~pal(value), opacity = .75, fillOpacity = .55) %>%
          addPolygons(data = d_aqs(), color = ~pal2(count)) %>%
          addLegend("bottomright", pal = pal, values = ~value,
                  title = "R\u00B2", opacity = .9) %>% 
          addLegend("bottomleft", pal = pal2, values = ~count, bins = 5,
                    title = "Number of Measurements at Monitor", opacity = .9) 
      } else {#if (d_user()$metric == 'ci_coverage'){
        leafletProxy("map", data = d_user()) %>%
          clearShapes() %>%
          clearControls() %>%
          addPolygons(color = ~pal(value), opacity = .75, fillOpacity = .55) %>%
          addPolygons(data = d_aqs(), color = ~pal2(count)) %>%
          addLegend("bottomright", pal = pal, values = ~value,
                  title = "95% CI Coverage (%)", opacity = .9) %>% 
          addLegend("bottomleft", pal = pal2, values = ~count, bins = 5,
                    title = "Number of Measurements at Monitor", opacity = .9)
      }#if loop
  }) #observe selections
  
  #show a popup table upon clicking
  showtablePopup <- function(poptable, lat, lng) {
    d_table <- readRDS('d_map_oob.rds')
    
    coords <- data.frame(lng, lat) %>%
      st_as_sf(coords = c('lng', 'lat'), crs = 4326)

    d_table <-  d_table %>%
      st_intersection(coords)

    d_table <- d_table %>%
      select(time, mae, rmse, rsq, ci_coverage) %>% 
      st_drop_geometry()
    
    pop_table <- d_table %>%
      htmlTable::txtRound(digits = 2) %>% 
      htmlTable::addHtmlTableStyle(col.columns = c("none", "#F7F7F7"),
                                   css.cell = "padding-left: .5em; padding-right: .2em;",
                                   css.header = "padding-left: .3em; padding-right: .3em;",
                                   align.header = "ccccc") %>% 
      htmlTable::htmlTable(header = c('Temporal Resolution', 'MAE', 'RMSE', 'R\u00B2',
                                      '95% CI Coverage'), rnames = FALSE) 
    
    leafletProxy("map") %>% addPopups(lng = lng, lat = lat, pop_table, layerId = poptable)
    
  }#table function
  
  #popup table click event
  observe({
    leafletProxy("map") %>%
      clearPopups()
    
    event <- input$map_shape_click
    if (is.null(event))
      return()
    
    isolate({
      showtablePopup(event$id, event$lat, event$lng)
    })
  }) #observe click
  
} #server function

h2map <- function(){
  shinyApp(ui, server)
}

h2map()

#testing----
# if (metric == "mae") { #mae selected
#   d_user <- d_user %>%
#     select(h3, time, n, mae, geometry)
# } else if (metric == "rmse") { # rmse selected
#   d_user <- d_user %>%
#     select(h3, time, n, rmse, geometry)
# } else if (metric == "rsq") { # rsq selected
#   d_user <- d_user %>%
#     select(h3, time, n, rsq, geometry)
# } else if (metric == "slope") { # slope selected
#   d_user <- d_user %>%
#     select(h3, time, n, slope, geometry)
# } else { # ci coverage selected
#   d_user <- d_user %>%
#     select(h3, time, n, ci_coverage, geometry)
#   
#   #metric <- input$err
#   
#   # if (metric == "mae") { #mae selected
#   #   d_user() <- d_user() %>%
#   #     select(h3, time, n, mae, geometry)
#   # } else if (metric == "rmse") { # rmse selected
#   #   d_user() <- d_user() %>%
#   #     select(h3, time, n, rmse, geometry)
#   # } else if (!is.null(d_user()$rsq) & metric == "rsq") { # rsq selected
#   #   d_user() <- d_user() %>%
#   #     select(h3, time, n, rsq, geometry)
#   # } else if (metric == "slope") { # slope selected
#   #   d_user() <- d_user() %>%
#   #     select(h3, time, n, slope, geometry)
#   # } else { # ci coverage selected
#   #   d_user() <- d_user() %>%
#   #     select(h3, time, n, ci_coverage, geometry)
#   # }
# }
# 
# pal <- colorNumeric("viridis", domain = d_user[,colnames(d_user %in% metric)])
# 
# # 
# d_map_oob_long <- d_map_oob %>%
#   select(-oob) %>%
#   pivot_longer(cols = c(mae,rmse,rsq,slope,ci_coverage),
#                names_to = "metric",
#                values_to = "value")
# # 
# 
# saveRDS(d_map_oob_long, "d_map_long.rds")
# 
# d_user <- d_map_oob_long %>%
#   filter(time == 'annual' & metric == 'mae')
# 
# #Test leaflet plot
# pal <- colorNumeric(palette = "viridis", domain = d_user$value)
# 
# leaflet(d_user) %>%
#   addTiles() %>%
#   addPolygons(color = ~pal(value))
# 
# #popup table testing
# 
# d_table <- readRDS('d_map_oob.rds')
# 
# d_table2 <- d_table %>%
#   filter( h3 == '824457fffffffff') %>%
#   select(time, n, mae, rmse, rsq, slope, ci_coverage) %>%
#   sf::st_drop_geometry()
# 
# d_table2 %>% DT::datatable(colnames = c('Temporal Resolution', 
#                                         'N', 'MAE', 'RMSE', 'R\u00B2',
#                                         'Slope', '95% CI Coverage'),
#                            rownames = F) %>% DT::formatRound(columns = c(3:6), digits = 3)
# 
# d_table2 %>%
#   htmlTable::txtRound(excl.cols = c(1,2,7), digits =3) %>% 
#   htmlTable::addHtmlTableStyle(col.columns = c("none", "#d0d3d4")) %>% 
#   htmlTable::htmlTable(header = c('Temporal Resolution', 
#                                   'N', 'MAE', 'RMSE', 'R\u00B2',
#                                   'Slope', '95% CI Coverage'), rnames = FALSE) 
#  


