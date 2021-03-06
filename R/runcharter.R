#' Create run chart with highlighted improvements where applicable
#'
#'This will plot the original dataframe, with highlighted runs of improvement.
#'It will also return a dataframe showing the improvment data
#'
#'
#' @param df  dataframe containing columns "date", "y", "grp"
#' @param med_rows   number of rows to base the initial median calculation over
#' @param runlength how long a run of consecutive points should be before re-basing the median
#' @param chart_title title for the  final chart
#' @param chart_subtitle subtitle for chart
#' @param direction look for runs "below" or "above" the median, or "both"
#' @param faceted if you  dont need a faceted / trellis display set this to FALSE
#' @param facet_cols the number of columns required for a faceted plot. Ignored if faceted is set to FALSE
#' @param save_plot should the plot be saved?  Calls ggsave on the last plot, saving in the current directory, if TRUE.
#' @param plot_extension one of "png","pdf" or other valid extension for saving ggplot2 plots. Used in the call to ggsave.
#' @param ... further arguments passed on to function
#'
#' @return run chart(s) and a dataframe showing sustained run data if appropriate
#'
#' @import ggplot2
#' @import dplyr
#' @importFrom utils head
#' @export
#'
#'@examples
#'\donttest{
#'runcharter(signals, med_rows = 13, runlength = 9,
#'chart_title = "Automated runs analysis",
#'direction = "above", faceted = TRUE,
#'facet_cols = 2, save_plot = TRUE, plot_extension = "png")
#'}
#'
#'
#
runcharter <-
  function(df,
           med_rows = 13,
           runlength = 9,
           chart_title = NULL,
           chart_subtitle = NULL,
           direction = "below",
           faceted = TRUE,
           facet_cols = NULL,
           save_plot = FALSE,
           plot_extension = "png",
           verbose = FALSE,
           ...) {
    
    median_baseline_colour = "#E87722" # Light orange
    runchart_line_colour = "#005EB8" # Royal blue
    runchart_rebasing_dots_colour = "#DB1884" # Magenta
    
    baseplot <- function(df, chart_title, chart_subtitle,
                         draw_start_baseline = TRUE, ...) {
      runchart <- ggplot2::ggplot(df, aes(date, y, group = 1)) +
        ggplot2::geom_line(colour = runchart_line_colour, size = 1.1)  +
        ggplot2::geom_point(
          shape = 21 ,
          colour = runchart_line_colour,
          fill = runchart_line_colour,
          size = 2.5) +

        ggplot2::theme_minimal(base_size = 10) +
        theme(axis.text.y = element_text(angle = 0)) +
        theme(axis.text.x = element_text(angle = 90)) +
        theme(panel.grid.minor = element_blank(),
              panel.grid.major = element_blank()) +
        ggplot2::ggtitle(label = chart_title,
                         subtitle = chart_subtitle) +
        ggplot2::labs(x = "", y = "") +
        theme(legend.position = "bottom") +
        
        ggplot2::geom_line(
          data = median_rows,
          aes(x = date, y = baseline, group = 1),
          colour = median_baseline_colour,
          size = 1.05,
          linetype = 1)

      if (draw_start_baseline) {
        runchart <-
          runchart + ggplot2::geom_line(
            data = df,
            aes(x = date, y = StartBaseline, group = 1),
            colour = median_baseline_colour,
            size = 1.05,
            linetype = 2)
      }

      return(runchart)
    }
    
    sustained_runs_results_as_list <-function (df,
                                        saved_sustained,
                                        chart_title = NULL,
                                        chart_subtitle = NULL,
                                        verbose_message) {
      sustained <- bind_rows(saved_sustained)
      sustained <- sustained_processing(sustained)
      
      runchart <- if (is.null(chart_title)) {
        susplot(df, sustained)
      } else {
        susplot(df, sustained, chart_title, chart_subtitle)
      }

      if (!faceted) {
        if (save_plot) {
          ggsave(filename)
        }
        if (verbose) {
          message(verbose_message)
        }
      }
      results <-
        list(
          runchart = runchart,
          sustained = sustained,
          median_rows = median_rows,
          StartBaseline = StartBaseline
        )
      return(results)
    }
    
    no_runs_results_as_list <-function (df,
                                        chart_title = NULL,
                                        chart_subtitle = NULL) {
      runchart <- baseplot(df, chart_title, chart_subtitle)
      if (!faceted) {
        if (save_plot) {
          ggsave(filename)
        }
        if (verbose) {
          message("no sustained runs found")
        }
      }
      results <-
        list(
          runchart = runchart,
          median_rows = median_rows,
          StartBaseline = StartBaseline
        )
      return(results)
    }

    susplot <- function(df, susdf, ...) {

      summary_sustained <- susdf %>%
        dplyr::group_by(grp,rungroup, improve,startdate,enddate,lastdate) %>%
        dplyr::summarise() %>%
        dplyr::ungroup() %>%
        dplyr::group_by(grp) %>%
        dplyr::mutate(runend = lead(enddate)) %>%
        dplyr::ungroup() %>%
        dplyr::mutate(runend = case_when
                      (!is.na(runend) ~ runend,
                        TRUE~ lastdate))

      runchart <- baseplot(df, chart_title, chart_subtitle,
                            draw_start_baseline = FALSE,...)

      runchart <- runchart +
        ggplot2::geom_point(
          data = susdf,
          aes(x = date, y = y, group = rungroup),
          shape = 21,
          colour = runchart_line_colour,
          fill = runchart_rebasing_dots_colour ,
          size = 2.7) +

        ggplot2::geom_segment(
          data = summary_sustained,
          aes(x = startdate,
              xend = enddate,
              y = improve,
              yend = improve,
              group = rungroup),
          colour = median_baseline_colour,
          linetype = 1,
          size = 1.05) +

        ggplot2::geom_segment(
          data = summary_sustained,
          aes(x = enddate,
              xend = runend,
              y = improve,
              yend = improve,
              group = rungroup),
          colour = median_baseline_colour,
          linetype = 2,
          size = 1.05)

      remaining <- dplyr::anti_join(df,susdf, 
                                    by = c("grp", "y", "date"))
      temp_summary_sustained <- summary_sustained %>%
        group_by(grp) %>%
        filter(startdate == min(startdate)) %>%
        select(grp,startdate)

      finalrows <- dplyr::left_join(remaining, temp_summary_sustained,
                                    by = "grp")

      runchart <- runchart +
        ggplot2::geom_segment(data = finalrows,
          aes(x = min(finalrows$date),
            xend = startdate,
            y = StartBaseline,
            yend = StartBaseline,
            group = grp),
          colour = median_baseline_colour,
          linetype = 2,
          size = 1.05) +
        ggplot2::ggtitle(label = chart_title, 
                         subtitle = chart_subtitle)
    }

    sustained_processing <- function(sustained) {
      sustained <- sustained %>%
        dplyr::arrange(date) %>%
        dplyr::mutate(rungroup = cumsum_with_reset_group(abs(flag), 
                                                         abs(flag_reset)))

      sustained <- sustained %>%
        dplyr::group_by(grp, rungroup) %>%
        dplyr::mutate(
          startdate = min(date),
          enddate = max(date),
          lastdate = max(df[["date"]])
        ) %>%
        dplyr::ungroup()
      sustained
    }

    extractor <- function(df = working_df){
      testdata <- df[which(df[["date"]] > enddate), ]
      testdata <- testdata[which(testdata[["y"]] != Baseline), ]
      testdata <- testdata %>% 
        dplyr::select(grp,y,date)

    }

    testdata_setup <- function(testdata) {
      testdata[["flag"]] <- sign(testdata[["y"]] -  Baseline)
      testdata[["rungroup"]] <- myrleid(testdata[["flag"]])

      if (direction == "below") {
        testdata <- testdata %>%
          dplyr::group_by(grp, rungroup) %>%
          dplyr::mutate(cusum = cumsum_with_reset_neg(flag, runlength*-1)) %>%
          dplyr::ungroup()
      } else if (direction == "above") {
        testdata <- testdata %>%
          dplyr::group_by(grp, rungroup) %>%
          dplyr::mutate(cusum = cumsum_with_reset(flag, runlength)) %>%
          dplyr::ungroup()
      } else {

        testdata <- testdata %>%
          dplyr::group_by(grp, rungroup) %>%
          dplyr::mutate(cusum_lo = cumsum_with_reset_neg(flag, runlength * -1),
                        cusum_hi = cumsum_with_reset(flag, abs(flag_reset))) %>%
          dplyr::mutate(cusum = pmax(cusum_hi,abs(cusum_lo))) %>%
          dplyr::ungroup() %>%
          dplyr::select(-cusum_hi,-cusum_lo)
      }


    }

    group_count <-  df %>% 
      dplyr::select(grp) %>% 
      dplyr::n_distinct()

    if (faceted == TRUE & group_count > 1) {
      build_facet(
        df,
        mr = med_rows,
        rl = runlength,
        ct = chart_title,
        cs = chart_subtitle,
        direct = direction,
        faceted = TRUE,
        n_facets = facet_cols,
        sp = save_plot,
        plot_extension
      )
    } else {
      # setup
      df <- df %>% dplyr::arrange(date)
      df[["grp"]] <-  as.character(df[["grp"]])

      # Find the number of observations in each group.
      # Only keep those who are longer than our runlength + median rows (default 20)
      # Drop the length and keep just the group names
      keep <- df %>% group_by(grp) %>% dplyr::count()
      keep <- keep %>% filter(n >= (med_rows + runlength))
      keep <- keep %>% pull(grp)

      # working_df is a dataframe of only the groups with enough
      # observations
      working_df <- df %>% filter(grp %in% keep)

      # Set enddate to be the date of the 13th row (the first date beyond our first median line)
      enddate <- working_df[["date"]][med_rows]

      # Make a new dataframe, median_rows, containing only the first 13 rows.
      median_rows <- head(working_df, med_rows)
      # Create a new column, 'baseline', which contains the median 
      median_rows[["baseline"]] <- median(median_rows[["y"]])

      # Calculate the median of the 'y' column in the median_rows dataframe
      Baseline <- median(head(working_df[["y"]], med_rows))

      # Duplicate this value as 'StartBaseline'
      StartBaseline <- Baseline

      flag_reset <-
        ifelse(direction == "below", runlength * -1, runlength)
      remaining_rows <- dim(working_df)[1] - med_rows
      saved_sustained <- list()
      results <- list()
      i <- 1

      current_grp <- unique(df[["grp"]])
      filename <- paste0(current_grp, ".", plot_extension)


      ### first pass##

      if (!remaining_rows > runlength)
        stop("Not enough rows remaining beyond the baseline period")


      testdata <- extractor(working_df)

      if (dim(testdata)[1] < 1) {
        return(no_runs_results_as_list(df,
                                       chart_title = NULL,
                                       chart_subtitle = NULL))
      }

      testdata <- testdata_setup(testdata)
      breakrow <- which.max(testdata[["cusum"]] == flag_reset)
      startrow <- breakrow - (abs(runlength) - 1)

      #  if no runs at all - print the chart
      #   return the chart object  so it can be modified by the user


      if (startrow < 1) {
        return(no_runs_results_as_list(df,
                                       chart_title = NULL,
                                       chart_subtitle = NULL))
      }

      #   if  we get to this point there is at least one run
      #   save the current sustained run, and the end date for future subsetting
      #   return the chart object  so it can be modified by the user
      #   return the sustained dataframe also


      startdate <- testdata[["date"]][startrow]
      enddate <-  testdata[["date"]][breakrow]
      tempdata <- testdata[startrow:breakrow, ]
      tempdata[["improve"]] <- median(tempdata[["y"]])
      saved_sustained[[i]] <- tempdata

      Baseline <- median(tempdata[["y"]])

      testdata <- extractor(working_df)

      remaining_rows <- dim(testdata)[1]

      # if not enough rows remaining, print the sustained run chart
      # return the run chart object
      # return the sustained dataframe

      if (remaining_rows < abs(runlength)) {
        return(
          sustained_runs_results_as_list(df,
                                         saved_sustained,
                                         NULL,
                                         NULL,
                                         "Improvements noted, not enough rows remaining for further analysis")
        )
      }
      i <- i + 1

      remaining_rows <- dim(testdata)[1]
      while (remaining_rows >= runlength) {
        # if we still have enough rows remaining then we look for the next run

        {
          # return rows beyond the current end date
          testdata <- extractor(working_df)

          # check that are still rows remaining in case all
          # rows are equal to the baseline value



          if (dim(testdata)[1] < 1) {
            return(
              sustained_runs_results_as_list(df,
                saved_sustained,
                NULL,
                NULL,
                "Improvements noted, not enough rows remaining for further analysis")
            )
          }


          # repeat the set up and check for runs of correct length

          testdata <- testdata_setup(testdata)

          breakrow <- which.max(testdata[["cusum"]] == flag_reset)
          startrow <- breakrow - (abs(runlength) - 1)

          # if there are no more runs of the required length,
          # print sustained chart and quit

          if (startrow < 1) {
            return(
              sustained_runs_results_as_list(df,
                saved_sustained,
                chart_title,
                chart_subtitle,
                "all sustained runs found, not enough rows remaining for analysis")
            )
            break
          }

          # else, carry on with processing the latest sustained run

          startdate <- testdata[["date"]][startrow]
          enddate <-  testdata[["date"]][breakrow]
          tempdata <- testdata[startrow:breakrow, ]
          tempdata[["improve"]] <- median(tempdata[["y"]])
          saved_sustained[[i]] <- tempdata

          Baseline <- median(tempdata[["y"]])
          testdata <- extractor(working_df)

          remaining_rows <- dim(testdata)[1]
          i <- i + 1

          # if not enough rows remaining now,  no need to analyse further
          # print the current sustained chart

          if (remaining_rows < abs(runlength)) {
            return(
              sustained_runs_results_as_list(df,
                                             saved_sustained,
                                             chart_title,
                                             chart_subtitle,
            "all sustained runs found, not enough rows remaining for analysis")
            )
            break
          }
          remaining_rows <- dim(testdata)[1]
        }
        remaining_rows <- dim(testdata)[1]
        if (remaining_rows < runlength) {
          break
        }
      }
    }
  }
