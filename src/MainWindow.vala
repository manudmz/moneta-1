/*
* Copyright(c) 2011-2019 Matheus Fantinel
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or(at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Matheus Fantinel <matfantinel@gmail.com>
*/

using Soup;
using Json;

namespace Moneta {
    public class MainWindow : Gtk.ApplicationWindow {
        public Gtk.Label label_result;
        public Gtk.Label label_info;
        public Gtk.ComboBox source_currency;
        public Gtk.ComboBox target_currency;
        public Gtk.Stack stack;
        public Gtk.Image aicon;

        public double avg;
        public string source_iso;
        public string target_iso;

        AppSettings settings;

        public MainWindow(Gtk.Application application) {
            GLib.Object(application: application,
                         icon_name: "com.github.matfantinel.moneta",
                         resizable: false,
                         height_request: 280,
                         width_request: 500,
                         border_width: 6
            );
        }        

        construct {
            setup_window_styles();

            settings = AppSettings.get_default();

            var icon = new Gtk.Image.from_icon_name("com.github.matfantinel.moneta-symbolic", Gtk.IconSize.DIALOG);

            setup_comboboxes();

            if(settings.source >= 0) {
                source_currency.set_active((Currency)(settings.source));
                source_iso = ((Currency)settings.source).get_iso_code();
            } else {
                source_currency.set_active(Currency.US_DOLLAR);
                source_iso = Currency.US_DOLLAR.get_iso_code();
            }

            if(settings.target >= 0) {
                target_currency.set_active((Currency)(settings.target));
                target_iso = ((Currency)settings.target).get_iso_code();
            } else {
                target_currency.set_active(Currency.US_DOLLAR);
                target_iso = Currency.US_DOLLAR.get_iso_code();
            }

            label_result = new Gtk.Label("");
            label_result.set_halign(Gtk.Align.END);
            label_result.hexpand = true;
            label_info = new Gtk.Label(_("Updated every hour"));
            label_info.set_halign(Gtk.Align.END);
            label_info.hexpand = true;
            label_result.set_halign(Gtk.Align.START);

            get_values();
            set_labels();

            var grid = new Gtk.Grid();
            grid.margin_top = 0;
            grid.column_homogeneous = true;
            grid.column_spacing = 6;
            grid.row_spacing = 6;
            grid.attach(icon, 0, 2, 1, 1);
            grid.attach(source_currency, 0, 1, 2, 1);
            grid.attach(target_currency, 2, 1, 2, 1);
            grid.attach(label_result, 1, 2, 3, 2);
            grid.attach(label_info, 1, 4, 3, 2);

            stack = new Gtk.Stack();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            stack.margin = 6;
            stack.margin_top = 0;
            stack.homogeneous = true;
            stack.add_named(grid, "money");

            this.add(stack);
            stack.show_all();

            source_currency.changed.connect(() => {
                get_values();
                set_labels();
            });

            target_currency.changed.connect(() => {
                get_values();
                set_labels();
            });

            Timeout.add_seconds(1800,() => {
                get_values();
                set_labels();
            });

            int x = settings.window_x;
            int y = settings.window_y;
            int coin = source_currency.get_active();
            coin = settings.source;
            int vcoin = target_currency.get_active();
            vcoin = settings.target;

            if(x != -1 && y != -1) {
                move(x, y);
            }

            button_press_event.connect((e) => {
                if(e.button == Gdk.BUTTON_PRIMARY) {
                    begin_move_drag((int) e.button,(int) e.x_root,(int) e.y_root, e.time);
                    return true;
                }
                return false;
            });
        }

        public void setup_window_styles() {
            var provider = new Gtk.CssProvider();
            provider.load_from_resource("/com/github/matfantinel/moneta/stylesheet.css");
            Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            stick();

            var titlebar = new Gtk.HeaderBar();
            titlebar.has_subtitle = false;
            titlebar.show_close_button = true;


            var titlebar_style_context = titlebar.get_style_context();
            titlebar_style_context.add_class(Gtk.STYLE_CLASS_FLAT);
            titlebar_style_context.add_class("default-decoration");
            titlebar_style_context.add_class("moneta-toolbar");

            this.set_titlebar(titlebar);

            this.get_style_context().add_class("rounded");            
        }

        public void setup_comboboxes() {
            string[] currencies = {
                Currency.US_DOLLAR.get_friendly_name(),
                Currency.BRAZILIAN_REAL.get_friendly_name(),
                Currency.EURO.get_friendly_name(),
                Currency.POUND_STERLING.get_friendly_name()
            };
            Gtk.ListStore source_list_store = new Gtk.ListStore(1, typeof(string));

            for (int i = 0; i < currencies.length; i++){
                Gtk.TreeIter iter;
                source_list_store.append (out iter);
                source_list_store.set (iter, 0, currencies[i]);
            }
    
            source_currency = new Gtk.ComboBox.with_model(source_list_store);
            source_currency.margin = 6;

            Gtk.CellRendererText source_cell = new Gtk.CellRendererText();
            source_currency.pack_start(source_cell, false);

            source_currency.set_attributes(source_cell, "text", 0);

            Gtk.ListStore target_list_store = new Gtk.ListStore(1, typeof(string));

            for (int i = 0; i < currencies.length; i++){
                Gtk.TreeIter iter;
                target_list_store.append (out iter);
                target_list_store.set (iter, 0, currencies[i]);
            }
    
            target_currency = new Gtk.ComboBox.with_model(target_list_store);
            target_currency.margin = 6;

            Gtk.CellRendererText target_cell = new Gtk.CellRendererText();
            target_currency.pack_start(target_cell, false);

            target_currency.set_attributes(target_cell, "text", 0);
        }

        public bool get_values() {
            settings.source = source_currency.get_active();
            if(settings.source >= 0) {
                source_iso = ((Currency)settings.source).get_iso_code();
            } else {
                source_currency.set_active(Currency.US_DOLLAR);
                source_iso = Currency.US_DOLLAR.get_iso_code();
            }


            settings.target = target_currency.get_active();
            if(settings.target >= 0) {
                target_iso = ((Currency)settings.target).get_iso_code();
            } else {
                target_currency.set_active(Currency.US_DOLLAR);
                target_iso = Currency.US_DOLLAR.get_iso_code();
            }
            
            var uri = "https://www.freeforexapi.com/api/live?pairs=" + target_iso + source_iso;
            
            stdout.printf("\n🎉️ "+ uri);
            var session = new Soup.Session();
            var message = new Soup.Message("GET", uri);
            session.send_message(message);

            try {
                var parser = new Json.Parser();

                stdout.printf("\n🎉️ "+ (string)message.response_body.flatten().data);

                parser.load_from_data((string) message.response_body.flatten().data, -1);
                var root_object = parser.get_root().get_object();
                var rates_object = root_object.get_object_member("rates");
                var response_object = rates_object.get_object_member(target_iso + source_iso);
                avg = response_object.get_double_member("rate");
            } catch(Error e) {
                warning("Failed to connect to service: %s", e.message);
            }

            return true;
        }

        public void set_labels() {
            var settings = AppSettings.get_default();
            var curr_symbol = "";
            settings.source = source_currency.get_active();
            curr_symbol = ((Currency)settings.source).get_symbol();

            var vcurr_symbol = "";
            settings.target = target_currency.get_active();
            vcurr_symbol = ((Currency)settings.target).get_symbol();            

            label_result.set_markup("""<span font="22">%s</span> <span font="30">%.4f</span> <span font="18">/ 1 %s</span>""".printf(curr_symbol, avg, vcurr_symbol));
        }
    }
}